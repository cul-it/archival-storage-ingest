# frozen_string_literal: true

class IngestWorker < Workers::Worker
  # Pass s3_manager only for tests.
  def initialize(s3_manager = nil)
    @s3_manager = s3_manager || ArchivalStorageIngest.configuration.s3_manager
  end

  def work(msg)
    s3_key = @s3_manager.manifest_key(msg.ingest_id, 'ingest_manifest')
    @s3_manager.upload_file(s3_key, msg.ingest_manifest)

    true
  end
end