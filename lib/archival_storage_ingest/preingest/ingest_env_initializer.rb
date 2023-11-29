# frozen_string_literal: true

require 'archival_storage_ingest/exception/ingest_exception'
require 'archival_storage_ingest/manifests/manifests'
require 'archival_storage_ingest/manifests/manifest_merger'
require 'archival_storage_ingest/manifests/manifest_missing_attribute_populator'
require 'archival_storage_ingest/manifests/manifest_to_filesystem_comparator'
require 'archival_storage_ingest/manifests/manifest_checker'
require 'archival_storage_ingest/messages/ingest_message'
require 'archival_storage_ingest/preingest/base_env_initializer'
require 'fileutils'
require 'json'
require 'yaml'

module Preingest
  class IngestEnvInitializer < BaseEnvInitializer
    attr_reader :file_identifier, :manifest_validator

    def initialize(ingest_root:, sfs_root:, manifest_validator:, file_identifier:)
      super(ingest_root:, sfs_root:)

      @file_identifier = file_identifier
      @manifest_validator = manifest_validator
    end

    # We need to run initialize_env first to populate depositor/collection from ingest manifest
    # and compare it to the provided values.
    def initialize_ingest_env(named_params)
      initialize_env(named_params)

      unless depositor == named_params.fetch(:depositor) &&
             collection_id == named_params.fetch(:collection_id)
        msg = "Depositor/Collection mismatch!\n  " \
              "Given values: #{named_params.fetch(:depositor)}/#{named_params.fetch(:collection_id)}  " \
              "Manifest values: #{depositor}/#{collection_id}"
        raise IngestException, msg
      end
    end

    # Add data integrity check after copying ingest manifest to correct place
    def _initialize_ingest_manifest(named_params)
      im_path = super
      manifest = _populate_missing_attribute(ingest_manifest: im_path, source_path:)
      raise IngestException, 'Asset mismatch' unless _compare_asset_existence(ingest_manifest: manifest)

      other_checksum_checker = Manifests::ManifestNonDefaultChecksumChecker.new
      other_checksum_checker.check_non_default_checksums(ingest_manifest: manifest)
      @manifest_validator.validate_ingest_manifest(manifest:)

      size_checker = Manifests::ManifestFilesizeChecker.new
      @total_size, @size_mismatch = size_checker.check_filesize(manifest:)

      im_path
    end

    def _populate_missing_attribute(ingest_manifest:, source_path:)
      mmap = Manifests::ManifestMissingAttributePopulator.new(file_identifier:)
      manifest = mmap.populate_missing_attribute_from_file(manifest: ingest_manifest, source_path:)
      File.write(ingest_manifest, JSON.pretty_generate(manifest.to_json_ingest_hash))

      manifest
    end

    def _compare_asset_existence(ingest_manifest:)
      mfc = Manifests::ManifestToFilesystemComparator.new
      mfc.compare_manifest_to_filesystem(manifest: ingest_manifest)
    end

    def _initialize_collection_manifest(im_path:, named_params:)
      manifest = if named_params.fetch(:cmf) == NO_COLLECTION_MANIFEST
                   _def_create_collection_manifest(im_path:, sfs_location: named_params.fetch(:sfs_location))
                 else
                   _merge_ingest_manifest_to_collection_manifest(imf: im_path, cmf: named_params.fetch(:cmf),
                                                                 sfs_loc: named_params.fetch(:sfs_location))
                 end
      _store_collection_manifest(manifest:)
    end

    def _def_create_collection_manifest(im_path:, sfs_location:)
      manifest = Manifests.read_manifest(filename: im_path)

      if manifest.locations.count.zero?
        update_locations(storage_manifest: manifest, s3_location: full_s3_location,
                         sfs_location: full_sfs_location(sfs_location:))
      end

      manifest.walk_packages { |package| package.source_path = nil }

      manifest
    end

    def _merge_ingest_manifest_to_collection_manifest(imf:, sfs_loc:, cmf:)
      cm = Manifests.read_manifest(filename: cmf)
      im = Manifests.read_manifest(filename: imf)
      mm = Manifests::ManifestMerger.new
      merged = mm.merge_manifests(storage_manifest: cm, ingest_manifest: im)
      update_locations(storage_manifest: merged,
                       s3_location: full_s3_location,
                       sfs_location: full_sfs_location(sfs_location: sfs_loc))
    end

    def update_locations(storage_manifest:, s3_location:, sfs_location:)
      storage_manifest.locations << s3_location unless storage_manifest.locations.include? s3_location
      storage_manifest.locations << sfs_location unless storage_manifest.locations.include? sfs_location
      storage_manifest
    end

    def _store_collection_manifest(manifest:)
      manifest_dir = File.join(collection_root, 'manifest')
      collection_manifest_dir = File.join(manifest_dir, 'collection_manifest')
      cm_filename = Manifests.collection_manifest_filename(depositor:, collection: collection_id)
      FileUtils.mkdir_p(collection_manifest_dir)
      manifest_path = File.join(collection_manifest_dir, cm_filename)

      json_to_write = JSON.pretty_generate(manifest.to_json_storage_hash)
      File.write(manifest_path, json_to_write)
    end

    def generate_config(ingest_manifest_path:, named_params:)
      { type: work_type, depositor:, collection: collection_id,
        dest_path: dest_path(sfs_location: named_params.fetch(:sfs_location)),
        ingest_manifest: ingest_manifest_path, ticket_id: named_params.fetch(:ticket_id) }
    end

    def dest_path(sfs_location:)
      File.join(sfs_root, sfs_location, depositor, collection_id)
    end

    def work_type
      IngestMessage::TYPE_INGEST
    end

    def config_path
      File.join(collection_root, 'config', 'ingest_config.yaml')
    end
  end
end
