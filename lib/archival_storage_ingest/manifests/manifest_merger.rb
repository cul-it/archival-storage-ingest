# frozen_string_literal: true

module Manifests
  class ManifestMerger
    # Merges packages of ingest manifest to storage manifest
    def merge_manifests(storage_manifest:, ingest_manifest:)
      ingest_manifest.walk_packages do |ingest_package|
        storage_package = storage_manifest.get_package(package_id: ingest_package.package_id)
        if storage_package.nil?
          storage_manifest.add_package(package: ingest_package)
        else
          merge_packages(storage_package: storage_package, ingest_package: ingest_package)
        end
      end
      storage_manifest
    end

    def merge_packages(storage_package:, ingest_package:)
      storage_files = storage_file_listing(storage_package: storage_package)
      ingest_package.walk_files do |file|
        storage_package.add_file(file: file) unless storage_files[file.filepath]
      end
    end

    def storage_file_listing(storage_package:)
      filepath = {}
      storage_package.walk_files do |file|
        filepath[file.filepath] = 1
      end
      filepath
    end
  end
end
