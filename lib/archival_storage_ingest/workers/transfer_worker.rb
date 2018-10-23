# frozen_string_literal: true

require 'archival_storage_ingest/workers/worker'

module TransferWorker
  class S3Transferer < Workers::Worker
    def start;
    end

    def status;
    end
  end

  class SFSTransferer < Workers::Worker
    def start;
    end

    def status;
    end
  end
end
