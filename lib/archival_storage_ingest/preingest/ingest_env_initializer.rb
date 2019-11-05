# frozen_string_literal: true

require 'archival_storage_ingest/exception/ingest_exception'
require 'archival_storage_ingest/manifests/manifests'
require 'archival_storage_ingest/manifests/manifest_merger'
require 'archival_storage_ingest/manifests/manifest_missing_attribute_populator'
require 'archival_storage_ingest/manifests/manifest_to_filesystem_comparator'
require 'archival_storage_ingest/messages/ingest_message'
require 'fileutils'
require 'yaml'

module Preingest
  DEFAULT_INGEST_ROOT = '/cul/app/archival_storage_ingest/ingest'
  DEFAULT_SFS_ROOT    = '/cul/data'
  NO_COLLECTION_MANIFEST = 'none'

  class IngestEnvInitializer
    attr_accessor :ingest_root, :sfs_root, :depositor, :collection_id, :collection_root,
                  :data_root, :source_path

    def initialize(ingest_root:, sfs_root:)
      @ingest_root   = ingest_root
      @sfs_root      = sfs_root
      @depositor     = nil
      @collection_id = nil
      @data_root     = nil
      @source_path   = nil
    end

    # :imf, :cmf, :data, :sfs_location, :ticket_id are used
    #
    # This way of coding does make RUBOCOP happy but it is hard to track down
    # which parameters are used where...
    # Is there a better way to deal with this situation?
    def initialize_ingest_env(named_params)
      _init_attrs(named_params.fetch(:imf))
      @source_path = _initialize_data(named_params)
      im_path = _initialize_ingest_manifest(named_params)
      _initialize_collection_manifest(im_path: im_path, named_params: named_params)
      _initialize_config(ingest_manifest_path: im_path, named_params: named_params)
    end

    def _init_attrs(manifest_path)
      manifest = Manifests.read_manifest(filename: manifest_path)
      @depositor = manifest.depositor
      @collection_id = manifest.collection_id
      @collection_root = File.join(ingest_root, depositor, collection_id)
      @data_root = File.join(collection_root, 'data')
    end

    def _initialize_data(named_params)
      depositor_dir = File.join(data_root, depositor)
      FileUtils.mkdir_p(depositor_dir)
      FileUtils.ln_s(named_params.fetch(:data), depositor_dir)
      File.join(depositor_dir, collection_id)
    end

    def _initialize_ingest_manifest(named_params)
      manifest_dir = File.join(collection_root, 'manifest')

      # ingest manifest
      ingest_manifest_dir = File.join(manifest_dir, 'ingest_manifest')
      im_path = _initialize_manifest(manifest_dir: ingest_manifest_dir, manifest_file: named_params.fetch(:imf))
      manifest = _populate_missing_attribute(ingest_manifest: im_path, source_path: source_path)
      raise IngestException, 'Asset mismatch' unless _compare_asset_existence(ingest_manifest: manifest)

      im_path
    end

    def _initialize_collection_manifest(im_path:, named_params:)
      return if named_params.fetch(:cmf).eql?(NO_COLLECTION_MANIFEST)

      manifest_dir = File.join(collection_root, 'manifest')
      collection_manifest_dir = File.join(manifest_dir, 'collection_manifest')
      cm_path = _initialize_manifest(manifest_dir: collection_manifest_dir, manifest_file: named_params.fetch(:cmf))
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

    def _initialize_config(ingest_manifest_path:, named_params:)
      ingest_config = generate_config(ingest_manifest_path: ingest_manifest_path, named_params: named_params)
      ingest_config_file = prepare_config_path
      File.open(ingest_config_file, 'w') { |file| file.write(ingest_config.to_yaml) }
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

    def prepare_config_path
      config = config_path
      parent = File.dirname(config)
      FileUtils.mkdir_p(parent)
      config
    end

    def config_path
      File.join(collection_root, 'config', 'ingest_config.yaml')
    end
  end
end
