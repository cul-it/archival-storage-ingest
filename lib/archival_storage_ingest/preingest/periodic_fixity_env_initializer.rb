# frozen_string_literal: true

require 'archival_storage_ingest/preingest/ingest_env_initializer'
require 'archival_storage_ingest/messages/ingest_message'
require 'archival_storage_ingest/workers/fixity_worker'

module Preingest
  DEFAULT_FIXITY_ROOT = '/cul/app/archival_storage_ingest/periodic_fixity'

  # It expects COLLECTION MANIFEST for the passed ingest_manifest_path argument!
  class PeriodicFixityEnvInitializer < IngestEnvInitializer
    def initialize(periodic_fixity_root:, sfs_root:)
      super(ingest_root: periodic_fixity_root, sfs_root: sfs_root)
    end

    # alias for initialize_ingest_env
    # sfs_location can be either a delimiter separated string or an array like data structure
    #   responding to 'each' method
    # cmf:, sfs_location:, ticket_id:
    def initialize_periodic_fixity_env(named_params)
      initialize_ingest_env(data: nil, cmf: NO_COLLECTION_MANIFEST, imf: named_params.fetch(:cmf),
                            sfs_location: named_params.fetch(:sfs_location), ticket_id: named_params.fetch(:ticket_id))
    end

    # Skip this step for periodic fixity check
    def _initialize_data(*); end

    def _initialize_ingest_manifest(named_params)
      manifest_dir = File.join(collection_root, 'manifest')

      # ingest manifest is collection manifest and does not need to
      # run additional checks to make sure every item has sha1.
      # The difference between manifest and data store will be
      # detected during the fixity check.
      im_dir = File.join(manifest_dir, 'ingest_manifest')
      _initialize_manifest(manifest_dir: im_dir, manifest_file: named_params.fetch(:imf))
    end

    # Skip this step for periodic fixity check
    def _compare_asset_existence(*)
      true
    end

    def generate_config(ingest_manifest_path:, named_params:)
      config = super(ingest_manifest_path: ingest_manifest_path, named_params: named_params)
      relay_queue_name = named_params.fetch(:relay_queue_name, nil)
      config[:queue_name] = relay_queue_name unless relay_queue_name.nil?
      config
    end

    def dest_path(sfs_location:)
      dest_paths = []
      sfs_location = sfs_location.split(FixityWorker::PeriodicFixitySFSGenerator::DEST_PATH_DELIMITER) unless
        sfs_location.respond_to?('each')
      sfs_location.each do |sfs|
        dest_paths << File.join(sfs_root, sfs, depositor, collection_id).to_s
      end
      dest_paths.join(FixityWorker::PeriodicFixitySFSGenerator::DEST_PATH_DELIMITER)
    end

    def work_type
      IngestMessage::TYPE_PERIODIC_FIXITY
    end

    def config_path
      File.join(collection_root, 'config', 'periodic_fixity_config.yaml')
    end
  end
end
