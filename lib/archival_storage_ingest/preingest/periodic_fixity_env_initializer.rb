# frozen_string_literal: true

require 'archival_storage_ingest/preingest/ingest_env_initializer'
require 'archival_storage_ingest/workers/fixity_worker'

module Preingest
  # It expects COLLECTION MANIFEST for the passed ingest_manifest_path argument!
  class PeriodicFixityEnvInitializer < IngestEnvInitializer
    DEFAULT_FIXITY_ROOT = '/cul/app/archival_storage_ingest/periodic_fixity'

    def initialize(periodic_fixity_root: DEFAULT_FIXITY_ROOT, sfs_root: DEFAULT_SFS_ROOT)
      super(ingest_root: periodic_fixity_root, sfs_root: sfs_root)
    end

    # alias for initialize_ingest_env
    def initialize_periodic_fixity_env(data:, cmf:, imf:, sfs_location:, ticket_id:)
      initialize_ingest_env(data: data, cmf: cmf, imf: imf, sfs_location: sfs_location, ticket_id: ticket_id)
    end

    def _initialize_config(collection_root:, sfs_location:, ingest_manifest_path:, ticket_id:)
      config_dir = File.join(collection_root, 'config')
      FileUtils.mkdir_p(config_dir)
      dest_path = dest_path(sfs_location: sfs_location)
      periodic_fixity_config = {
        depositor: depositor, collection: collection_id,
        dest_path: dest_path, ingest_manifest: ingest_manifest_path,
        ticket_id: ticket_id
      }
      periodic_fixity_config_file = File.join(config_dir, 'periodic_fixity_config.yaml')
      File.open(periodic_fixity_config_file, 'w') { |file| file.write(periodic_fixity_config.to_yaml) }
    end

    def dest_path(sfs_location:)
      dest_paths = []
      sfs_location.split(FixityWorker::PeriodicFixitySFSGenerator::DEST_PATH_DELIMITER).each do |sfs|
        dest_paths << File.join(sfs_root, sfs, depositor, collection_id).to_s
      end
      dest_paths.join(FixityWorker::PeriodicFixitySFSGenerator::DEST_PATH_DELIMITER)
    end
  end
end
