# frozen_string_literal: true

require 'archival_storage_ingest/workers/worker'
require 'archival_storage_ingest/manifests/manifests'
require 'archival_storage_ingest/ingest_utils/ingest_utils'
require 'find'
require 'json'
require 'pathname'

# We don't expect to encounter symlinks on fixity checker!
# We will store JSON on memory while generating it.
# If memory usage becomes an issue, then we will try sax-like approach.
module FixityWorker
  FIXITY_TEMPORARY_PACKAGE_ID = 'fixity_temporary_package'
  FIXITY_MANIFEST_TEMPLATE = {
    locations: [],
    packages: [
      {
        package_id: FIXITY_TEMPORARY_PACKAGE_ID,
        files: []
      }
    ]
  }.freeze
  FIXITY_MANIFEST_TEMPLATE_STR = JSON.generate(FIXITY_MANIFEST_TEMPLATE)

  class FixityGenerator < Workers::Worker
    # Pass s3_manager only for tests.
    def initialize(s3_manager = nil)
      @s3_manager = s3_manager || ArchivalStorageIngest.configuration.s3_manager
    end

    def worker_type
      raise NotImplementedError
    end

    def work(msg)
      manifest = generate_manifest(msg)

      manifest_s3_key = @s3_manager.manifest_key(msg.ingest_id, worker_type)
      # data = manifest.manifest_hash.to_json
      @s3_manager.upload_string(manifest_s3_key, manifest.to_json(json_type: Manifests::MANIFEST_TYPE_FIXITY))

      true
    end

    # Return checksum manifest of all objects for a given depositor/collection.
    def generate_manifest(msg)
      object_paths = object_paths(msg) # returns a hash of keys (dep/col/resource) to paths.
      path_prefix = "#{msg.depositor}/#{msg.collection}"
      manifest = Manifests::Manifest.new(json_text: FIXITY_MANIFEST_TEMPLATE_STR)
      fixity_package = manifest.get_package(package_id: FIXITY_TEMPORARY_PACKAGE_ID)
      object_paths.each do |object_path|
        (sha, size) = calculate_checksum("#{path_prefix}/#{object_path}", msg)
        fixity_package.add_file_entry(filepath: object_path, sha1: sha, size: size)
      end

      manifest
    end

    # This method must return a list of file paths starting from the depositor/collection.
    # It must not contain prefix such as /cul/data/archival01.
    # E.g. [RMC/RMA/RMA1234/dir1/file1.txt,
    #       RMC/RMA/RMA1234/dir2/file2.txt]
    # Not /cul/data/archival01/RMC/RMA/RMA1234/dir1/file1.txt
    def object_paths(_msg)
      raise NotImplementedError
    end

    def calculate_checksum(_path, _msg)
      raise NotImplementedError
    end
  end

  class IngestFixityGenerator < FixityGenerator
    def object_paths(msg)
      ingest_manifest = fetch_ingest_manifest(msg)
      paths = []
      ingest_manifest.walk_all_filepath do |file|
        paths << file.filepath
      end
      paths
    end

    def fetch_ingest_manifest(msg)
      manifest_s3_key = @s3_manager.manifest_key(msg.ingest_id, Workers::TYPE_INGEST)
      ingest_manifest = @s3_manager.retrieve_file(manifest_s3_key)
      Manifests::Manifest.new(json_text: ingest_manifest.string)
    end
  end

  class IngestFixityS3Generator < IngestFixityGenerator
    def name
      'S3 Fixity Generator'
    end

    def worker_type
      Workers::TYPE_S3
    end

    def calculate_checksum(object_path, _msg)
      @s3_manager.calculate_checksum(object_path)
    end
  end

  class PeriodicFixityS3Generator < FixityGenerator
    def name
      'Periodic S3 Fixity Generator'
    end

    def worker_type
      Workers::TYPE_S3
    end

    # Pass s3_manager only for tests.

    def calculate_checksum(path, _msg)
      @s3_manager.calculate_checksum(path)
    end

    private

    def object_paths(msg)
      @s3_manager.list_object_keys(msg.collection_s3_prefix)
    end
  end

  class IngestFixitySFSGenerator < IngestFixityGenerator
    def name
      'SFS Fixity Generator'
    end

    def worker_type
      Workers::TYPE_SFS
    end

    def calculate_checksum(object_path, msg)
      full_path = File.join(msg.dest_path, object_path).to_s
      IngestUtils.calculate_checksum(full_path)
    end
  end

  class PeriodicFixitySFSGenerator < FixityGenerator
    def name
      'Periodic SFS Fixity Generator'
    end

    def worker_type
      Workers::TYPE_SFS
    end

    # Pass s3_manager only for tests.

    def calculate_checksum(file_path, msg)
      full_path = File.join(msg.dest_path, file_path).to_s
      IngestUtils.calculate_checksum(full_path)
    end

    private

    def object_paths(msg)
      assets_dir = msg.effective_dest_path
      path_to_trim = Pathname.new(msg.dest_path)

      Find.find(assets_dir)
          .reject { |path| File.directory?(path) }
          .map { |path| Pathname.new(path).relative_path_from(path_to_trim).to_s }
    end
  end
end
