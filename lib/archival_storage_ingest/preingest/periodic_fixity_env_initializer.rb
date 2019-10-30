# frozen_string_literal: true

require 'archival_storage_ingest/preingest/ingest_env_initializer'
require 'archival_storage_ingest/messages/ingest_message'
require 'archival_storage_ingest/workers/fixity_worker'

module Preingest
  # It expects COLLECTION MANIFEST for the passed ingest_manifest_path argument!
  class PeriodicFixityEnvInitializer < IngestEnvInitializer
    DEFAULT_FIXITY_ROOT = '/cul/app/archival_storage_ingest/periodic_fixity'

    def initialize(periodic_fixity_root: DEFAULT_FIXITY_ROOT, sfs_root: DEFAULT_SFS_ROOT)
      super(ingest_root: periodic_fixity_root, sfs_root: sfs_root)
    end

    # alias for initialize_ingest_env
    def initialize_periodic_fixity_env(data:, cmf:, sfs_location:, ticket_id:)
      initialize_ingest_env(data: data, cmf: NO_COLLECTION_MANIFEST, imf: cmf, sfs_location: sfs_location, ticket_id: ticket_id)
    end

    def generate_config(sfs_location:, ingest_manifest_path:, ticket_id:)
      config = super(sfs_location: sfs_location, ingest_manifest_path:
                     ingest_manifest_path, ticket_id: ticket_id)
      config[:dest_path] = dest_path(sfs_location: sfs_location)
      config
    end

    # Skip this step for periodic fixity check
    def _compare_asset_existence(*)
      true
    end

    def dest_path(sfs_location:)
      dest_paths = []
      sfs_location.split(FixityWorker::PeriodicFixitySFSGenerator::DEST_PATH_DELIMITER).each do |sfs|
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
