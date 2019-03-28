# frozen_string_literal: true

module Workers
  TYPE_S3 = 's3'
  TYPE_SFS = 'sfs'
  TYPE_INGEST = 'ingest_manifest'

  # Base class for specific workers
  class Worker
    def work(msg) end

    def name; end
  end
end
