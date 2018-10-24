# frozen_string_literal: true

require 'archival_storage_ingest/workers/worker'

module TransferWorker
  class S3Transferer < Workers::Worker
    def work(msg) end
  end

  class SFSTransferer < Workers::Worker
    def work(msg) end
  end
end
