# frozen_string_literal: true

require 'archival_storage_ingest/workers/worker'

module FixityWorker
  class S3FixityGenerator < Workers::Worker
    def work(msg) end
  end

  class SFSFixityGenerator < Workers::Worker
    def work(msg) end
  end
end
