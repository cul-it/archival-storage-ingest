# frozen_string_literal: true

require 'archival_storage_ingest/workers/worker'
require 'archival_storage_ingest/workers/manifest'
require 'digest/sha1'
require 'find'
require 'json'
require 'pathname'

# We don't expect to encounter symlinks on fixity checker!
# We will store JSON on memory while generating it.
# If memory usage becomes an issue, then we will try sax-like approach.
#
# Until CULAR-1588 gets finalized, use old manifest format.

module FixityWorker
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
      data = manifest.to_old_manifest(msg.depositor, msg.collection).to_json
      @s3_manager.upload_string(manifest_s3_key, data)

      true
    end

    # Return checksum manifest of all objects for a given depositor/collection.
    def generate_manifest(msg)
      object_paths = object_paths(msg) # returns a hash of keys (dep/col/resource) to paths.

      manifest = WorkerManifest::Manifest.new
      object_paths.each do |object_path|
        (sha, size) = calculate_checksum(object_path, msg)
        manifest.add_file(object_path, sha, size)
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
      ingest_manifest.files.keys
    end

    def fetch_ingest_manifest(msg)
      manifest_s3_key = @s3_manager.manifest_key(msg.ingest_id, Workers::TYPE_INGEST)
      ingest_manifest = @s3_manager.retrieve_file(manifest_s3_key)
      WorkerManifest.parse_old_manifest(ingest_manifest)
    end
  end

  class IngestFixityS3Generator < IngestFixityGenerator
    def worker_type
      Workers::TYPE_S3
    end

    def calculate_checksum(object_path, _msg)
      @s3_manager.calculate_checksum(object_path)
    end
  end

  class PeriodicFixityS3Generator < FixityGenerator
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
    BUFFER_SIZE = 4096

    def worker_type
      Workers::TYPE_SFS
    end

    def calculate_checksum(object_path, msg) # rubocop:disable Metrics/MethodLength
      full_path = File.join(msg.dest_path, object_path).to_s
      size = 0
      File.open(full_path, 'rb') do |file|
        dig = Digest::SHA1.new
        until file.eof?
          buffer = file.read(BUFFER_SIZE)
          dig.update(buffer)
          size += buffer.length
        end
        return dig.hexdigest, size
      end
    end
  end

  class PeriodicFixitySFSGenerator < FixityGenerator
    BUFFER_SIZE = 4096

    def worker_type
      Workers::TYPE_SFS
    end

    # Pass s3_manager only for tests.

    def calculate_checksum(file_path, msg)
      full_path = File.join(msg.dest_path, file_path).to_s
      File.open(full_path, 'rb') do |file|
        dig = Digest::SHA1.new
        until file.eof?
          buffer = file.read(BUFFER_SIZE)
          dig.update(buffer)
        end
        dig.hexdigest
      end
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
