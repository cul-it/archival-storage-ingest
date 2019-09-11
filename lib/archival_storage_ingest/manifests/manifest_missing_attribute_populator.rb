# frozen_string_literal: true

require 'archival_storage_ingest/ingest_utils/ingest_utils'
require 'archival_storage_ingest/manifests/manifests'

# This module won't verify checksum, only fill in missing checksum and file size
# It will replace all source_path with the passed value.
# It expects to get the absolute path of the asset by combining source_path and filepath.
# If each package may have different source_path, the this module needs to be updated.
module Manifests
  class ManifestMissingAttributePopulator
    def populate_missing_attribute(manifest:, source_path:)
      manifest.walk_packages do |package|
        package.source_path = source_path
        package.walk_files do |file|
          full_path = File.join(source_path, file.filepath)
          (file.sha1, _size) = IngestUtils.calculate_checksum(full_path) if IngestUtils.blank?(file.sha1)
          file.size = File.size?(full_path) if file.size.nil?
        end
      end
      manifest
    end

    def to_file(destination:, manifest:, json_type: Manifests::MANIFEST_TYPE_INGEST)
      File.open(destination, 'w') { |file| file.puts manifest.to_json(json_type: json_type) }
    end
  end
end
