# frozen_string_literal: true

require 'archival_storage_ingest/workers/worker'

class LogWorker < Workers::Worker
  def initialize(issue_tracker:)
    super(_name)
    @issue_tracker = issue_tracker
  end

  def _name
    'Logger'
  end

  def platform
    IngestMessage::PLATFORM_SERVERFARM
  end

  def work(msg)
    @issue_tracker.notify_status(ingest_msg: msg)

    true
  end
end
