# frozen_string_literal: true

require 'archival_storage_ingest/ingest_utils/ingest_params'
require 'yaml'

module Preingest
  DEFAULT_INGEST_ROOT = '/cul/app/archival_storage_ingest/ingest'
  DEFAULT_FIXITY_ROOT = '/cul/app/archival_storage_ingest/periodic_fixity'
  DEFAULT_SFS_ROOT    = '/cul/data'
  NO_COLLECTION_MANIFEST = 'none'

  class BaseEnvInitializer
    attr_accessor :total_size, :size_mismatch
    attr_reader :ingest_root, :sfs_root, :depositor, :collection_id, :ingest_params,
                :collection_root, :data_root

    def initialize(ingest_root:, sfs_root:)
      @ingest_root   = ingest_root
      @sfs_root      = sfs_root
      @ingest_params = nil
      @total_size    = 0
      @size_mismatch = {}
    end

    # takes filepath of ingest_params
    def initialize_env(ingest_params:)
      initialize_env_from_params_obj(IngestUtils::IngestParams.new(ingest_params))
    end

    # takes IngestUtils::IngestParams object
    def initialize_env_from_params_obj(ingest_params:)
      @ingest_params = ingest_params
      _init_attrs
      im_path = _initialize_ingest_manifest
      _initialize_collection_manifest(im_path:)
      _initialize_config(im_path:)
    end

    def _init_attrs
      manifest = Manifests.read_manifest(filename: ingest_params.ingest_manifest)
      @depositor = manifest.depositor
      @collection_id = manifest.collection_id
      @collection_root = File.join(ingest_root, depositor, collection_id)
      @data_root = File.join(collection_root, 'data')
    end

    def _initialize_ingest_manifest
      manifest_dir = File.join(collection_root, 'manifest')

      # ingest manifest
      ingest_manifest_dir = File.join(manifest_dir, 'ingest_manifest')
      _initialize_manifest(manifest_dir: ingest_manifest_dir, manifest_file: ingest_params.ingest_manifest)
    end

    def _initialize_collection_manifest(im_path:)
      raise "Do something with #{im_path}!"
    end

    def _initialize_manifest(manifest_dir:, manifest_file:)
      FileUtils.mkdir_p(manifest_dir)
      manifest_path = File.join(manifest_dir, File.basename(manifest_file))
      FileUtils.copy_file(manifest_file, manifest_path)
      manifest_path
    end

    def full_s3_location
      "s3://s3-cular/#{depositor}/#{collection_id}"
    end

    def full_sfs_location(sfs_location:)
      "smb://files.cornell.edu/lib/#{sfs_location}/#{depositor}/#{collection_id}"
    end

    def _initialize_config(im_path:)
      ingest_params = generate_config(ingest_manifest_path: im_path)
      ingest_params_file = prepare_config_path

      File.write(ingest_params_file, ingest_params.to_yaml)
    end

    def generate_config(ingest_manifest_path:); end

    def dest_path(sfs_location:)
      raise "Do something with #{sfs_location}!"
    end

    def work_type; end

    def prepare_config_path
      config = config_path
      parent = File.dirname(config)
      FileUtils.mkdir_p(parent)
      config
    end

    def config_path; end
  end
end
