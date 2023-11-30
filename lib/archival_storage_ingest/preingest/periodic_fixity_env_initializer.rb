# frozen_string_literal: true

require 'archival_storage_ingest/messages/ingest_message'
require 'archival_storage_ingest/preingest/base_env_initializer'
require 'archival_storage_ingest/workers/fixity_worker'

module Preingest
  # It expects COLLECTION MANIFEST for the passed ingest_manifest_path argument!
  class PeriodicFixityEnvInitializer < BaseEnvInitializer
    def initialize(periodic_fixity_root:, sfs_root:)
      super(ingest_root: periodic_fixity_root, sfs_root:)
    end

    # alias for initialize_ingest_env
    # sfs_location can be either a delimiter separated string or an array like data structure
    #   responding to 'each' method
    # cmf:, sfs_location:, ticket_id: are used
    def initialize_periodic_fixity_env(named_params)
      named_params[:imf] = named_params.fetch(:cmf)
      named_params[:data] = nil
      initialize_env(named_params)
    end

    # Not really needed but...
    def _initialize_collection_manifest(im_path:, named_params:) # rubocop:disable Lint/UnusedMethodArgument
      manifest_dir = File.join(collection_root, 'manifest')
      cm_dir = File.join(manifest_dir, 'collection_manifest')
      _initialize_manifest(manifest_dir: cm_dir, manifest_file: im_path)
    end

    def generate_config(ingest_manifest_path:, named_params:)
      config = {
        type: work_type, depositor:, collection: collection_id,
        dest_path: dest_path(sfs_location: named_params.fetch(:sfs_location)),
        ingest_manifest: ingest_manifest_path, ticket_id: named_params.fetch(:ticket_id)
      }
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
