# frozen_string_literal: true

require 'archival_storage_ingest/workers/worker'
require 'archival_storage_ingest/manifests/manifests'

module FixityCompareWorker
  class ManifestComparator < Workers::Worker
    attr_reader :s3_manager

    # Pass s3_manager only for tests.
    def initialize(s3_manager = nil)
      @s3_manager = s3_manager || ArchivalStorageIngest.configuration.s3_manager
    end

    def work(msg) # rubocop:disable Metrics/MethodLength
      s3_manifest = retrieve_manifest(msg, Workers::TYPE_S3)
      sfs_manifest = retrieve_manifest(msg, Workers::TYPE_SFS)
      ingest_manifest = retrieve_manifest(msg, Workers::TYPE_INGEST)

      if ingest_manifest.flattened != sfs_manifest.flattened
        raise IngestException, "Ingest and SFS manifests do not match: #{ingest_manifest.diff(sfs_manifest)}"
      end

      if ingest_manifest.flattened != s3_manifest.flattened
        raise IngestException, "Ingest and S3 manifests do not match: #{ingest_manifest.diff(s3_manifest)}"
      end

      true
    rescue Aws::S3::Errors::NoSuchKey
      false
    end

    def name
      'Manifest Comparator'
    end

    private

    def retrieve_manifest(msg, suffix)
      manifest_name = s3_manager.manifest_key(msg.ingest_id, suffix)
      manifest_file = s3_manager.retrieve_file(manifest_name)
      Manifests.read_manifest_io(json_io: manifest_file)
    end
  end
end
