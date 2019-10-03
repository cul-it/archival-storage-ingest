# frozen_string_literal: true

require 'archival_storage_ingest/ingest_utils/ingest_utils'
require 'archival_storage_ingest/manifests/manifests'
require 'archival_storage_ingest/workers/fixity_worker'

# This module won't verify checksum, only fill in missing checksum and file size
module Manifests
  class ManifestGenerator
    attr_reader :depositor, :collection_id, :ingest_manifest

    def initialize(depositor:, collection_id:, ingest_manifest: nil)
      @depositor = depositor
      @collection_id = collection_id
      @ingest_manifest = ingest_manifest
    end

    def generate_manifest
      manifest = Manifests::Manifest.new(json_text: FixityWorker::FIXITY_MANIFEST_TEMPLATE_STR)
      package = manifest.packages[0]
      keys = list_keys
      keys.each do |key|
        (sha1, size) = calculate_checksum(key)
        package.add_file_entry(filepath: manifest_key(key), sha1: sha1, size: size)
      end
      manifest
    end

    def list_keys
      return list_all_keys if @ingest_manifest.nil?

      manifest = Manifests.read_manifest(filename: @ingest_manifest)
      keys = []
      manifest.walk_all_filepath do |file|
        keys << im_key_to_regular_key(file.filepath)
      end
      keys
    end

    def list_all_keys; end

    def calculate_checksum(key); end

    def im_key_to_regular_key(_key); end

    def manifest_key(key); end
  end

  class ManifestGeneratorS3 < Manifests::ManifestGenerator
    attr_reader :s3_manager, :s3_prefix

    def initialize(depositor:, collection_id:, s3_manager:, ingest_manifest: nil)
      super(depositor: depositor, collection_id: collection_id, ingest_manifest: ingest_manifest)
      @s3_manager = s3_manager
      @s3_prefix = "#{depositor}/#{collection_id}"
    end

    def im_key_to_regular_key(im_key)
      "#{depositor}/#{collection_id}/#{im_key}"
    end

    def list_all_keys
      s3_manager.list_object_keys(s3_prefix)
    end

    def calculate_checksum(s3_key)
      s3_manager.calculate_checksum(s3_key)
    end

    def manifest_key(s3_key)
      IngestUtils.relative_path(s3_key, s3_prefix)
    end
  end

  class ManifestGeneratorSFS < Manifests::ManifestGenerator
    attr_reader :data_path

    def initialize(depositor:, collection_id:, data_path:, ingest_manifest: nil)
      super(depositor: depositor, collection_id: collection_id, ingest_manifest: ingest_manifest)
      @data_path = data_path
    end

    def im_key_to_regular_key(im_key)
      File.join(data_path, im_key)
    end

    def list_all_keys
      filesystem_listing = []
      directory_walker = IngestUtils::DirectoryWalker.new
      directory_walker.process_immediate_children(data_path) do |path|
        filesystem_listing << path if File.file?(path)
      end
      directory_walker.process_rest(data_path) do |path|
        filesystem_listing << path if File.file?(path)
      end
      filesystem_listing
    end

    def calculate_checksum(filepath)
      IngestUtils.calculate_checksum(filepath)
    end

    def manifest_key(filepath)
      IngestUtils.relative_path(filepath, data_path)
    end
  end
end
