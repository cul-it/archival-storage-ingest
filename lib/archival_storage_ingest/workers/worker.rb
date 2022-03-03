# frozen_string_literal: true

module Workers
  TYPE_S3 = 's3'
  TYPE_SFS = 'sfs'
  TYPE_INGEST = 'ingest_manifest'

  # Base class for specific workers
  class Worker
    attr_reader :name
    attr_writer :platform

    def initialize(worker_name)
      @name = worker_name
      @platform = platform
    end

    def work(msg); end

    def platform; end
  end
end
