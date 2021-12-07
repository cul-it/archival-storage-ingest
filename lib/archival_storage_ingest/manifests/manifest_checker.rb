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

  class ManifestNonDefaultChecksumChecker
    def check_non_default_checksums(ingest_manifest:)
      errors = []
      ingest_manifest.walk_packages do |package|
        package.walk_files do |file|
          (status, error) = _check_non_default_checksums(source_path: package.source_path, file: file)
          errors << error unless status
        end
      end
      raise IngestException, errors.join("\n") unless errors.empty?
    end

    def _check_non_default_checksums(source_path:, file:)
      file.list_checksum_info.each do |algorithm, checksum|
        next if algorithm.to_s.downcase == IngestUtils::ALGORITHM_SHA1

        path = File.join(source_path, file.filepath)
        calculated = IngestUtils.calculate_checksum(filepath: path, algorithm: algorithm.to_s)
        return false, "Fixity mismatch: #{path} (#{algorithm}): provided: #{checksum}, calculated: #{calculated}"
      end

      true
    end
  end
end
