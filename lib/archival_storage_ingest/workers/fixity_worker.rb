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
# SFS workers expect dest_path/filepath to be the absolute path of an asset.
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
    attr_reader :debug, :logger

    # Pass s3_manager only for tests.
    def initialize(s3_manager = nil)
      super(_name)
      @s3_manager = s3_manager || ArchivalStorageIngest.configuration.s3_manager
      @debug = ArchivalStorageIngest.configuration.debug
      @logger = ArchivalStorageIngest.configuration.logger
    end

    def _name; end

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
    # It is expected that object_path DOES NOT contain depositor/collection prefix!
    def generate_manifest(msg)
      object_paths = object_paths(msg) # returns a hash of keys (dep/col/resource) to paths.
      manifest = Manifests::Manifest.new(json_text: FIXITY_MANIFEST_TEMPLATE_STR)
      fixity_package = manifest.get_package(package_id: FIXITY_TEMPORARY_PACKAGE_ID)
      object_paths.each do |object_path|
        logger.debug("Calculate checksum for #{object_path} started") if debug
        (sha, size, errors) = calculate_checksum(object_path, msg)
        log_checksum_output(sha, size, errors) if debug
        fixity_package.add_file_entry(filepath: object_path, sha1: sha, size: size)
      end

      manifest
    end

    def log_checksum_output(sha, size, errors)
      logger.debug("Checksum: #{sha}, #{size}")
      return if errors.nil?

      errors.each do |error|
        logger.debug("Error: #{error}")
      end
    end

    # This method must return a list of file paths same as what's in the manifest.
    # It must not contain prefix such as /cul/data/archival01, depositor or collection.
    # E.g. [dir1/file1.txt,
    #       dir2/file2.txt]
    # Not /cul/data/archival01/RMC/RMA/RMA1234/dir1/file1.txt or
    #     RMC/RMA/RMA1234/dir1/file1.txt
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
    def _name
      'S3 Fixity Generator'
    end

    def worker_type
      Workers::TYPE_S3
    end

    def calculate_checksum(object_path, msg)
      s3_key = "#{msg.collection_s3_prefix}/#{object_path}"
      @s3_manager.calculate_checksum(s3_key)
    end
  end

  class PeriodicFixityS3Generator < FixityGenerator
    def _name
      'Periodic S3 Fixity Generator'
    end

    def worker_type
      Workers::TYPE_S3
    end

    def calculate_checksum(object_path, msg)
      s3_key = "#{msg.collection_s3_prefix}/#{object_path}"
      @s3_manager.calculate_checksum(s3_key)
    end

    # We expect object_paths to return same format as filepath in manifest.
    # Remove collection prefix.
    def object_paths(msg)
      object_paths = @s3_manager.list_object_keys("#{msg.collection_s3_prefix}/")
      ops = object_paths.map { |path| path.sub("#{msg.collection_s3_prefix}/", '') }
      logger.debug("Object keys: #{ops}") if debug

      ops
    end
  end

  class IngestFixitySFSGenerator < IngestFixityGenerator
    def _name
      'SFS Fixity Generator'
    end

    def worker_type
      Workers::TYPE_SFS
    end

    def calculate_checksum(object_path, msg)
      full_path = File.join(msg.dest_path, object_path).to_s
      IngestUtils.calculate_checksum(filepath: full_path)
    end
  end

  class PeriodicFixitySFSGenerator < FixityGenerator
    DEST_PATH_DELIMITER = ','

    def _name
      'Periodic SFS Fixity Generator'
    end

    def worker_type
      Workers::TYPE_SFS
    end

    def calculate_checksum(file_path, msg)
      checksum = ''
      msg.dest_path.split(DEST_PATH_DELIMITER).each do |dest_path|
        full_path = File.join(dest_path, file_path).to_s
        next unless File.exist?(full_path)

        checksum = IngestUtils.calculate_checksum(filepath: full_path)
        break
      end
      checksum
    end

    def object_paths(msg)
      obj_paths = []
      msg.dest_path.split(DEST_PATH_DELIMITER).each do |dest_path|
        obj_paths += Find.find(dest_path)
                         .reject { |path| File.directory?(path) }
                         .map { |path| Pathname.new(path).relative_path_from(dest_path).to_s }
      end
      obj_paths
    end
  end
end
