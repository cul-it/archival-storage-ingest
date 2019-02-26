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

    def generate_manifest(msg)
      object_keys = object_key_paths(msg) # returns a hash of keys (dep/col/resource) to paths.

      manifest = Manifest.new
      object_keys.each do |s3_key, path|
        manifest.add_file(s3_key, calculate_checksum(path))
      end

      manifest
    end

    def object_key_paths(_msg)
      raise NotImplementedError
    end

    def calculate_checksum(_path)
      raise NotImplementedError
    end
  end

  class S3FixityGenerator < FixityGenerator
    def worker_type
      Workers::TYPE_S3
    end

    # Pass s3_manager only for tests.

    def calculate_checksum(path)
      @s3_manager.calculate_checksum(path)
    end

    private

    def object_key_paths(msg)
      @s3_manager.list_object_keys(msg.collection_s3_prefix)
        .map { |x| [x, x] }.to_h
    end
  end

  class SFSFixityGenerator < FixityGenerator
    BUFFER_SIZE = 4096

    def worker_type
      Workers::TYPE_SFS
    end

    # Pass s3_manager only for tests.

    def calculate_checksum(file_path)
      File.open(file_path, 'rb') do |file|
        dig = Digest::SHA1.new
        until file.eof?
          buffer = file.read(BUFFER_SIZE)
          dig.update(buffer)
        end
        dig.hexdigest
      end
    end

    private

    def object_key_paths(msg)
      assets_dir = msg.effective_dest_path
      path_to_trim = Pathname.new(msg.dest_path)

      Find.find(assets_dir)
        .reject { |path| File.directory?(path) }
        .map { |path| [Pathname.new(path).relative_path_from(path_to_trim).to_s, path] }
        .to_h
    end
  end
end
