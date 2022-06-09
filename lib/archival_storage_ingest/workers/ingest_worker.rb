# frozen_string_literal: true

require 'archival_storage_ingest/workers/worker'

class IngestWorker < Workers::Worker
  # Pass s3_manager only for tests.
  def initialize(application_logger, s3_manager = nil)
    super(application_logger)
    @s3_manager = s3_manager || ArchivalStorageIngest.configuration.s3_manager
  end

  def _name
    'Ingest Initiator'
  end

  def _work(msg)
    s3_key = @s3_manager.manifest_key(msg.job_id, Workers::TYPE_INGEST)
    @s3_manager.upload_file(s3_key, msg.ingest_manifest)
    @application_logger.log(log_msg(msg, s3_key))

    true
  end

  def log_msg(msg, s3_key)
    {
      job_id: msg.job_id,
      log: "#{name} has deployed ingest manifest to S3 at '#{s3_key}'"
    }
  end
end
