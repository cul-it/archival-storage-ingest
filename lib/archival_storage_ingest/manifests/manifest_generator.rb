# frozen_string_literal: true

require 'archival_storage_ingest/ingest_utils/ingest_utils'
require 'archival_storage_ingest/manifests/manifests'
require 'archival_storage_ingest/workers/fixity_worker'

# This module won't verify checksum, only fill in missing checksum and file size
module Manifests
  class ManifestGenerator
    attr_reader :depositor, :collection_id

    def initialize(depositor:, collection_id:)
      @depositor = depositor
      @collection_id = collection_id
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

    def list_keys; end

    def calculate_checksum(key); end

    def manifest_key(key); end
  end

  class ManifestGeneratorS3 < Manifests::ManifestGenerator
    attr_reader :s3_manager, :s3_prefix

    def initialize(depositor:, collection_id:, s3_manager:)
      super(depositor: depositor, collection_id: collection_id)
      @s3_manager = s3_manager
      @s3_prefix = "#{depositor}/#{collection_id}"
    end

    def list_keys
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
    attr_reader :data_path, :start_path

    def initialize(depositor:, collection_id:, data_path:)
      super(depositor: depositor, collection_id: collection_id)
      @data_path = data_path
      @start_path = File.join(data_path, depositor, collection_id)
    end

    def list_keys
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
      IngestUtils.relative_path(filepath, start_path)
    end
  end
end
