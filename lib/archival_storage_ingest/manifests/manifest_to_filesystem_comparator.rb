# frozen_string_literal: true

require 'archival_storage_ingest/ingest_utils/ingest_utils'
require 'archival_storage_ingest/manifests/manifests'
require 'pathname'

module Manifests
  # It expects to find absolute path by combining source_path and filepath.
  # It will traverse source_path directly, not modifying it with depositor/collection information.
  class ManifestToFilesystemComparator
    def compare_manifest_to_filesystem(manifest:, source_path:)
      manifest_listing = populate_manifest_files(manifest: manifest)
      filesystem_listing = populate_filesystem(source_path: source_path)

      return true if manifest_listing == filesystem_listing

      print_diffs(manifest_listing: manifest_listing, filesystem_listing: filesystem_listing)

      false
    end

    def print_diffs(manifest_listing:, filesystem_listing:)
      not_in_filesystem = manifest_listing - filesystem_listing
      not_in_filesystem.each do |file|
        puts "#{file} is not in the file system!"
      end

      not_in_manifest = filesystem_listing - manifest_listing
      not_in_manifest.each do |file|
        puts "#{file} is not in the manifest!"
      end
    end

    def populate_manifest_files(manifest:)
      manifest_listing = []
      manifest.walk_all_filepath do |file|
        manifest_listing << file.filepath
      end
      manifest_listing.sort
    end

    def populate_filesystem(source_path:)
      filesystem_listing = []
      directory_walker = IngestUtils::DirectoryWalker.new
      directory_walker.process(source_path) do |path|
        filesystem_listing << IngestUtils.relative_path(path, source_path) if File.file?(path)
      end
      filesystem_listing.sort
    end
  end
end
