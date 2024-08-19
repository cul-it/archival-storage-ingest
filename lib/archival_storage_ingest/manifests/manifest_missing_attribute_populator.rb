# frozen_string_literal: true

require 'archival_storage_ingest/ingest_utils/ingest_utils'
require 'archival_storage_ingest/manifests/manifests'

# This module won't verify checksum, only fill in missing checksum and file size
# It will replace all source_path with the passed value.
# It expects to get the absolute path of the asset by combining source_path and filepath.
# If each package may have different source_path, the this module needs to be updated.
module Manifests
  class ManifestMissingAttributePopulator
    attr_reader :file_identifier

    def initialize(file_identifier:)
      @file_identifier = file_identifier
    end

    def populate_missing_attribute_from_file(manifest:, source_path:)
      # This function assumes the source paths are not resolved.
      manifest = Manifests.read_manifest(filename: manifest)
      _populate_missing_attribute(manifest:, source_path:)
    end

    def _populate_missing_attribute(manifest:, source_path:)
      manifest.walk_packages do |package|
        package.source_path = source_path
        package.walk_files do |file|
          populate_missing_attribute_for_file(package:, file:)
        end
      end

      manifest
    end

    def populate_missing_attribute(manifest:)
      # This function assumes the source paths are resolved.
      manifest.walk_packages do |package|
        package.walk_files do |file|
          populate_missing_attribute_for_file(package:, file:)
        end
      end

      manifest
    end

    def populate_missing_attribute_for_file(package:, file:) # rubocop:disable Metrics/AbcSize
      full_path = File.join(package.source_path, file.filepath)
      (file.sha1, _size) = IngestUtils.calculate_checksum(filepath: full_path) if IngestUtils.blank?(file.sha1)
      file.size = File.size?(full_path) if file.size.nil?

      file.media_type = file_identifier.identify_from_source(ingest_package: package, file:)
      file.tool_version = file_identifier.identify_tool
    end

    def to_file(destination:, manifest:, json_type: Manifests::MANIFEST_TYPE_INGEST)
      File.open(destination, 'w') { |file| file.puts manifest.to_json(json_type:) }
    end
  end
end
