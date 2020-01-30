# frozen_string_literal: true

require 'archival_storage_ingest/exception/ingest_exception'
require 'archival_storage_ingest/manifests/manifests'
require 'archival_storage_ingest/manifests/manifest_merger'
require 'archival_storage_ingest/manifests/manifest_missing_attribute_populator'
require 'archival_storage_ingest/manifests/manifest_to_filesystem_comparator'
require 'archival_storage_ingest/messages/ingest_message'
require 'archival_storage_ingest/preingest/base_env_initializer'
require 'fileutils'
require 'json'
require 'yaml'

module Preingest
  class IngestEnvInitializer < BaseEnvInitializer
    def initialize_ingest_env(named_params)
      initialize_env(named_params)
    end

    # Add data integrity check after copying ingest manifest to correct place
    def _initialize_ingest_manifest(named_params)
      im_path = super
      manifest = _populate_missing_attribute(ingest_manifest: im_path, source_path: source_path)
      raise IngestException, 'Asset mismatch' unless _compare_asset_existence(ingest_manifest: manifest)

      im_path
    end

    def _populate_missing_attribute(ingest_manifest:, source_path:)
      mmap = Manifests::ManifestMissingAttributePopulator.new
      manifest = mmap.populate_missing_attribute_from_file(manifest: ingest_manifest, source_path: source_path)
      json_to_write = JSON.pretty_generate(manifest.to_json_ingest_hash)
      File.open(ingest_manifest, 'w') { |file| file.write(json_to_write) }
      manifest
    end

    def _compare_asset_existence(ingest_manifest:)
      mfc = Manifests::ManifestToFilesystemComparator.new
      mfc.compare_manifest_to_filesystem(manifest: ingest_manifest)
    end

    def _initialize_collection_manifest(im_path:, named_params:)
      manifest_dir = File.join(collection_root, 'manifest')
      collection_manifest_dir = File.join(manifest_dir, 'collection_manifest')

      if named_params.fetch(:cmf).eql?(NO_COLLECTION_MANIFEST)
        _def_create_collection_manifest(im_path: im_path, cm_dir: collection_manifest_dir,
                                        sfs_location: named_params.fetch(:sfs_location))
      else
        _merge_ingest_manifest_to_collection_manifest(im_path: im_path, sfs_loc: named_params.fetch(:sfs_location),
                                                      cm_dir: collection_manifest_dir, cmf: named_params.fetch(:cmf))
      end
    end

    def _def_create_collection_manifest(im_path:, cm_dir:, sfs_location:)
      manifest = _initialize_cm_from_im(im_path: im_path, sfs_location: sfs_location)

      FileUtils.mkdir_p(cm_dir)
      cm_filename = Manifests.collection_manifest_filename(depositor: depositor, collection: collection_id)
      manifest_path = File.join(cm_dir, cm_filename)
      File.write(manifest_path, manifest.to_json_storage_hash.to_json)
      manifest_path
    end

    def _initialize_cm_from_im(im_path:, sfs_location:)
      manifest = Manifests.read_manifest(filename: im_path)

      if manifest.locations.count.zero?
        update_locations(storage_manifest: manifest, s3_location: full_s3_location,
                         sfs_location: full_sfs_location(sfs_location: sfs_location))
      end

      manifest.walk_packages do |package|
        package.source_path = nil
      end

      manifest
    end

    def _merge_ingest_manifest_to_collection_manifest(im_path:, sfs_loc:, cm_dir:, cmf:)
      cm_path = _initialize_manifest(manifest_dir: cm_dir, manifest_file: cmf)
      _merge_manifests(collection_manifest: cm_path, ingest_manifest: im_path, sfs_location: sfs_loc)
      cm_path
    end

    def _merge_manifests(collection_manifest:, ingest_manifest:, sfs_location:)
      mm = Manifests::ManifestMerger.new
      merged_manifest = mm.merge_manifest_files(storage_manifest: collection_manifest, ingest_manifest: ingest_manifest)
      merged_manifest = update_locations(storage_manifest: merged_manifest,
                                         s3_location: full_s3_location,
                                         sfs_location: full_sfs_location(sfs_location: sfs_location))
      json_to_write = JSON.pretty_generate(merged_manifest.to_json_storage_hash)
      File.open(collection_manifest, 'w') { |file| file.write(json_to_write) }
    end

    def update_locations(storage_manifest:, s3_location:, sfs_location:)
      storage_manifest.locations << s3_location unless storage_manifest.locations.include? s3_location
      storage_manifest.locations << sfs_location unless storage_manifest.locations.include? sfs_location
      storage_manifest
    end

    def generate_config(ingest_manifest_path:, named_params:)
      {
        type: work_type, depositor: depositor, collection: collection_id,
        dest_path: dest_path(sfs_location: named_params.fetch(:sfs_location)),
        ingest_manifest: ingest_manifest_path, ticket_id: named_params.fetch(:ticket_id)
      }
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
