# frozen_string_literal: true

require 'archival_storage_ingest/ingest_utils/ingest_utils'
require 'archival_storage_ingest/workers/worker'

class PeriodicFixityWorker < Workers::Worker
  # Pass s3_manager only for tests.
  def initialize(application_logger, s3_manager = nil)
    super(application_logger)
    @s3_manager = s3_manager || ArchivalStorageIngest.configuration.s3_manager
  end

  def _name
    'Periodic Fixity Initiator'
  end

  # Deploy ingest manifest to S3 and update transfer state to 'in_progress' for this job_id and each cloud platform
  def _work(msg)
    s3_key = @s3_manager.manifest_key(msg.job_id, Workers::TYPE_INGEST)
    @s3_manager.upload_file(s3_key, msg.ingest_manifest)
    true
  end

  def log_msg(msg, s3_key)
    {
      job_id: msg.job_id,
      log: "#{name} has deployed storage manifest to S3 at '#{s3_key}'"
    }
  end
end
