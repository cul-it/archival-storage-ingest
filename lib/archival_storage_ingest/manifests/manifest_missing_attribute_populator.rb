# frozen_string_literal: true

require 'archival_storage_ingest/ingest_utils/ingest_utils'
require 'archival_storage_ingest/manifests/manifests'

# This module won't verify checksum, only fill in missing checksum and file size
module Manifests
  class ManifestMissingAttributePopulator
    def populate_missing_attribute(manifest:, data_path:)
      path_prefix = File.join(data_path, manifest.depositor, manifest.collection_id)
      manifest.walk_all_filepath do |file|
        full_path = File.join(path_prefix, file.filepath)
        (file.sha1, _size) = IngestUtils.calculate_checksum(full_path) unless file.sha1.to_s.nil?
        file.size = File.size?(full_path) if file.size.nil?
      end
      manifest
    end

    def to_file(destination:, manifest:, json_type: Manifests::MANIFEST_TYPE_INGEST)
      File.open(destination, 'w') { |file| file.puts manifest.to_json(json_type: json_type) }
    end
  end
end
