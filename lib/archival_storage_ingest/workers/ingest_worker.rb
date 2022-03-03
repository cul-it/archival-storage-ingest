# frozen_string_literal: true

require 'archival_storage_ingest/messages/ingest_message'
require 'archival_storage_ingest/workers/worker'

class IngestWorker < Workers::Worker
  # Pass s3_manager only for tests.
  def initialize(s3_manager = nil)
    super(_name)
    @s3_manager = s3_manager || ArchivalStorageIngest.configuration.s3_manager
  end

  def _name
    'Ingest Initiator'
  end

  def platform
    IngestMessage::PLATFORM_SERVERFARM
  end

  def work(msg)
    s3_key = @s3_manager.manifest_key(msg.ingest_id, Workers::TYPE_INGEST)
    @s3_manager.upload_file(s3_key, msg.ingest_manifest)

    true
  end
end
