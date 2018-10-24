# frozen_string_literal: true

require 'archival_storage_ingest/workers/worker'

module FixityCompareWorker
  class ManifestComparator < Workers::Worker
    def work(msg) end
  end
end
