# frozen_string_literal: true

require 'archival_storage_ingest/exception/ingest_exception'
require 'archival_storage_ingest/manifests/manifests'
require 'archival_storage_ingest/manifests/manifest_merger'
require 'archival_storage_ingest/manifests/manifest_missing_attribute_populator'
require 'archival_storage_ingest/manifests/manifest_to_filesystem_comparator'
require 'fileutils'
require 'yaml'

module Preingest
  DEFAULT_INGEST_ROOT = '/cul/app/archival_storage_ingest/ingest'
  DEFAULT_SFS_ROOT    = '/cul/data'
  NONE_COLLECTION_MANIFEST = 'none'

  class IngestEnvInitializer
    attr_accessor :ingest_root, :sfs_root, :depositor, :collection_id,
                  :ingest_manifest, :collection_manifest, :ingest_config
    def initialize(ingest_root: DEFAULT_INGEST_ROOT, sfs_root: DEFAULT_SFS_ROOT)
      @ingest_root   = ingest_root
      @sfs_root      = sfs_root
      @depositor     = nil
      @collection_id = nil
      @ingest_manifest = nil
      @collection_manifest = nil
      @ingest_config = nil
    end

    def initialize_ingest_env(data:, cmf:, imf:, sfs_location:, ticket_id:)
      manifest = Manifests.read_manifest(filename: imf)
      @depositor = manifest.depositor
      @collection_id = manifest.collection_id
      collection_root = File.join(@ingest_root, @depositor, @collection_id)
      data_root = _initialize_data(collection_root: collection_root, data: data)
      @ingest_manifest, @collection_manifest = _initialize_manifests(collection_root: collection_root,
                                                                     cmf: cmf, imf: imf, data_root: data_root)
      @ingest_config = _initialize_config(collection_root: collection_root, sfs_location: sfs_location,
                                          ingest_manifest_path: ingest_manifest, ticket_id: ticket_id)
    end

    def _initialize_data(collection_root:, data:)
      data_root = File.join(collection_root, 'data')
      depositor_dir = File.join(data_root, depositor)
      FileUtils.mkdir_p(depositor_dir)
      FileUtils.ln_s(data, depositor_dir)
      File.join(depositor_dir, collection_id)
    end

    def _initialize_manifests(collection_root:, cmf:, imf:, data_root:)
      manifest_dir = File.join(collection_root, 'manifest')

      # ingest manifest
      ingest_manifest_dir = File.join(manifest_dir, 'ingest_manifest')
      im_path = _initialize_manifest(manifest_dir: ingest_manifest_dir, manifest_file: imf)
      manifest = _populate_missing_attribute(ingest_manifest: im_path, source_path: data_root)
      raise IngestException unless _compare_asset_existence(ingest_manifest: manifest)

      # collection manifest
      cm_path = setup_collection_manifest(manifest_dir: manifest_dir, im_path: im_path, cmf: cmf)

      [im_path, cm_path]
    end

    def setup_collection_manifest(manifest_dir:, im_path:, cmf:)
      return if cmf.eql?(NONE_COLLECTION_MANIFEST)

      collection_manifest_dir = File.join(manifest_dir, 'collection_manifest')
      cm_path = _initialize_manifest(manifest_dir: collection_manifest_dir, manifest_file: cmf)
      _merge_manifests(collection_manifest: cm_path, ingest_manifest: im_path)
      cm_path
    end

    def _initialize_manifest(manifest_dir:, manifest_file:)
      FileUtils.mkdir_p(manifest_dir)
      manifest_path = File.join(manifest_dir, File.basename(manifest_file))
      FileUtils.copy_file(manifest_file, manifest_path)
      manifest_path
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

    def _merge_manifests(collection_manifest:, ingest_manifest:)
      mm = Manifests::ManifestMerger.new
      merged_manifest = mm.merge_manifest_files(storage_manifest: collection_manifest, ingest_manifest: ingest_manifest)
      json_to_write = JSON.pretty_generate(merged_manifest.to_json_storage_hash)
      File.open(collection_manifest, 'w') { |file| file.write(json_to_write) }
    end

    def _initialize_config(collection_root:, sfs_location:, ingest_manifest_path:, ticket_id:)
      config_dir = File.join(collection_root, 'config')
      FileUtils.mkdir_p(config_dir)
      dest_path = File.join(sfs_root, sfs_location, depositor, collection_id)
      ingest_config = {
        depositor: depositor, collection: collection_id, dest_path: dest_path,
        ingest_manifest: ingest_manifest_path, ticket_id: ticket_id
      }
      ingest_config_file = File.join(config_dir, 'ingest_config.yaml')
      File.open(ingest_config_file, 'w') { |file| file.write(ingest_config.to_yaml) }
      ingest_config_file
    end
  end
end
