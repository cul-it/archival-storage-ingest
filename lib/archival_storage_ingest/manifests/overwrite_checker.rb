# frozen_string_literal: true

module Manifests
  class OverwriteChecker
    attr_reader :s3_manager

    def initialize(s3_manager:)
      @s3_manager = s3_manager
    end

    def check_overwrites(ingest_manifest:)
      depositor = ingest_manifest.depositor
      collection = ingest_manifest.collection_id
      overwrites = []
      ingest_manifest.walk_packages do |package|
        package.walk_files do |file|
          key = File.join(depositor, collection, file.filepath)
          overwrites << file.filepath if s3_manager.exist?(key:)
        end
      end
      overwrites
    end
  end
end
