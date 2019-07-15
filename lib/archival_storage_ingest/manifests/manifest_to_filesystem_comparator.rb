# frozen_string_literal: true

require 'archival_storage_ingest/ingest_utils/ingest_utils'
require 'archival_storage_ingest/manifests/manifests'
require 'pathname'

module Manifests
  class ManifestToFilesystemComparator
    def compare_manifest_to_filesystem(manifest:, data_path:)
      manifest_listing = populate_manifest_files(manifest: manifest)
      filesystem_listing = populate_filesystem(data_path: data_path)

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
      depositor_collection = "#{manifest.depositor}/#{manifest.collection_id}"
      manifest_listing = []
      manifest.walk_all_filepath do |file|
        manifest_listing << "#{depositor_collection}/#{file.filepath}"
      end
      manifest_listing.sort
    end

    def populate_filesystem(data_path:)
      prefix_to_trim = Pathname.new(data_path)
      filesystem_listing = []
      directory_walker = IngestUtils::DirectoryWalker.new
      directory_walker.process_immediate_children(data_path) do |path|
        filesystem_listing << IngestUtils.relative_path(path, prefix_to_trim) if File.file?(path)
      end
      directory_walker.process_rest(data_path) do |path|
        filesystem_listing << IngestUtils.relative_path(path, prefix_to_trim) if File.file?(path)
      end
      filesystem_listing.sort
    end
  end
end
