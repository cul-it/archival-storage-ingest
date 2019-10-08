# frozen_string_literal: true

require 'archival_storage_ingest/ingest_utils/ingest_utils'
require 'archival_storage_ingest/manifests/manifests'
require 'pathname'

module Manifests
  # It expects to find absolute path by combining source_path and filepath.
  # It will traverse source_path directly, not modifying it with depositor/collection information.
  class ManifestToFilesystemComparator
    def compare_manifest_to_filesystem(manifest:, source_path: nil)
      manifest_listing = populate_manifest_files(manifest: manifest)
      filesystem_listing = populate_filesystem(manifest: manifest, source_path: source_path)
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

    def populate_filesystem(manifest:, source_path:)
      source_paths = populate_source_path(manifest: manifest, source_path: source_path)
      filesystem_listing = []
      directory_walker = IngestUtils::DirectoryWalker.new
      source_paths.each do |sp|
        directory_walker.process(sp) do |path|
          filesystem_listing << IngestUtils.relative_path(path, sp) if File.file?(path)
        end
      end
      filesystem_listing.sort
    end

    def populate_source_path(manifest:, source_path:)
      if source_path
        return source_path if source_path.respond_to?('each')

        return [source_path]
      end

      source_paths = []
      manifest.walk_packages do |package|
        source_paths << package.source_path
      end
      source_paths.uniq
    end
  end
end
