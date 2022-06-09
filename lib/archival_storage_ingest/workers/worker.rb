# frozen_string_literal: true

module Workers
  TYPE_S3 = 's3'
  TYPE_SFS = 'sfs'
  TYPE_INGEST = 'ingest_manifest'

  # Base class for specific workers
  class Worker
    attr_reader :name

    def initialize(application_logger)
      @name = _name
      @application_logger = application_logger
    end

    def _name
      'Ingest Queuer'
    end

    def work(msg)
      _work(msg)
    rescue StandardError => e
      log_error(msg, e)
      raise
    end

    def log_error(msg, exception)
      log_doc = {
        job_id: msg.job_id,
        log: "#{name} encountered unrecoverable error: #{exception.message}"
      }
      @application_logger.log(log_doc)
    end

    def _work(msg); end
  end
end
