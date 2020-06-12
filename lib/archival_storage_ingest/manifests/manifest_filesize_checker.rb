# frozen_string_literal: true

require 'archival_storage_ingest/ingest_utils/ingest_utils'
require 'archival_storage_ingest/manifests/manifests'
require 'pathname'

module Manifests
  # It expects to find absolute path by combining source_path and filepath.
  # It will traverse source_path directly, not modifying it with depositor/collection information.
  class ManifestFilesizeChecker
    def check_filesize(manifest:)
      total = 0
      mismatch = {}
      manifest.walk_packages do |package|
        package.walk_files do |file|
          fs_size = File.new(File.join(package.source_path, file.filepath), 'r').size
          mismatch[file.filepath] = { manifest: file.size, fs: fs_size } if file.size != fs_size

          total += fs_size
        end
      end

      [total, mismatch]
    end
  end
end
