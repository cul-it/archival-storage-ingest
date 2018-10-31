# frozen_string_literal: true

require 'archival_storage_ingest/workers/worker'

module FixityCompareWorker
  class ManifestComparator < Workers::Worker
    attr_reader :s3_manager

    def initialize(s3_manager)
      @s3_manager = s3_manager
    end

    def work(msg)
      begin
        s3_manifest = s3_manager.retrieve_file(".manifests/#{msg.ingest_id}_S3.json")
        sfs_manifest = s3_manager.retrieve_file(".manifests/#{msg.ingest_id}_SFS.json")
      rescue Aws::S3::Errors::NoSuchKey
        return true
      end

      return true if s3_manifest == sfs_manifest

      false
    end
  end
end
