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

    def work(msg)
      s3_manifest = retrieve_manifest(msg, Workers::TYPE_S3)
      sfs_manifest = retrieve_manifest(msg, Workers::TYPE_SFS)
      ingest_manifest = retrieve_manifest(msg, Workers::TYPE_INGEST)

      raise IngestException, 'Ingest and SFS manifests do not match' unless ingest_manifest.flattened == sfs_manifest.flattened

      raise IngestException, 'Ingest and S3 manifests do not match' unless s3_manifest.flattened == ingest_manifest.flattened

      true
    rescue Aws::S3::Errors::NoSuchKey
      false
    end

    private

    def retrieve_manifest(msg, suffix)
      manifest_name = s3_manager.manifest_key(msg.ingest_id, suffix)
      manifest_file = s3_manager.retrieve_file(manifest_name)
      Manifests::Manifest.new(filename: manifest_name, json: manifest_file)
    end
  end
end
