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

module FixityWorker
  class S3FixityGenerator < Workers::Worker
    def work(msg) end
  end

  class SFSFixityGenerator < Workers::Worker
    BUFFER_SIZE = 4096

    # Pass s3_manager only for tests.
    def initialize(s3_manager = nil)
      @s3_manager = s3_manager || ArchivalStorageIngest.configuration.s3_manager
    end

    def work(msg)
      manifest = generate_manifest(msg)

      manifest_s3_key = @s3_manager.manifest_key(msg.ingest_id, Workers::TYPE_SFS)
      data = manifest.manifest_hash.to_json
      @s3_manager.upload_string(manifest_s3_key, data)

      true
    end

    def generate_manifest(msg)
      manifest = Manifest.new
      assets_dir = msg.effective_dest_path
      path_to_trim = Pathname.new(msg.dest_path)

      Find.find(assets_dir) do |path|
        next if File.directory?(path)

        sha1 = calculate_sha1(path)
        filepath = Pathname.new(path).relative_path_from(path_to_trim).to_s
        manifest.add_file(filepath, sha1.hexdigest)
      end

      manifest
    end

    def calculate_sha1(file_path)
      sha1 = File.open(file_path, 'rb') do |file|
        dig = Digest::SHA1.new
        until file.eof?
          buffer = file.read(BUFFER_SIZE)
          dig.update(buffer)
        end
        dig
      end
      sha1
    end
  end
end
