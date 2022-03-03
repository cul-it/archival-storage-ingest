# frozen_string_literal: true

require 'yaml'

module Preingest
  DEFAULT_INGEST_ROOT = '/cul/app/archival_storage_ingest/ingest'
  DEFAULT_FIXITY_ROOT = '/cul/app/archival_storage_ingest/periodic_fixity'
  DEFAULT_SFS_ROOT    = '/cul/data'
  NO_COLLECTION_MANIFEST = 'none'

  class BaseEnvInitializer
    attr_accessor :ingest_root, :sfs_root, :depositor, :collection_id, :collection_root,
                  :data_root, :source_path, :total_size, :size_mismatch, :platform

    def initialize(ingest_root:, sfs_root:, platform:)
      @ingest_root   = ingest_root
      @sfs_root      = sfs_root
      @platform      = platform
      @depositor     = nil
      @collection_id = nil
      @data_root     = nil
      @source_path   = nil
      @total_size    = 0
      @size_mismatch = {}
    end

    # :imf, :cmf, :data, :sfs_location, :ticket_id are used
    #
    # This way of coding does make RUBOCOP happy but it is hard to track down
    # which parameters are used where...
    # Is there a better way to deal with this situation?
    def initialize_env(named_params)
      _init_attrs(named_params.fetch(:imf))
      @source_path = named_params.fetch(:data)
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

    def _initialize_ingest_manifest(named_params)
      manifest_dir = File.join(collection_root, 'manifest')

      # ingest manifest
      ingest_manifest_dir = File.join(manifest_dir, 'ingest_manifest')
      _initialize_manifest(manifest_dir: ingest_manifest_dir, manifest_file: named_params.fetch(:imf))
    end

    def _initialize_collection_manifest(im_path:, named_params:)
      raise "Do something with #{im_path} & #{named_params}!"
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

    def _initialize_config(ingest_manifest_path:, named_params:)
      ingest_config = generate_config(ingest_manifest_path: ingest_manifest_path, named_params: named_params)
      ingest_config_file = prepare_config_path

      File.open(ingest_config_file, 'w') { |file| file.write(ingest_config.to_yaml) }
    end

    def generate_config(ingest_manifest_path:, named_params:); end

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
