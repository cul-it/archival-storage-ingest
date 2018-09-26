require 'archival_storage_ingest/version'
require 'archival_storage_ingest/messages/ingest_message'
require 'archival_storage_ingest/messages/poller'
require 'archival_storage_ingest/messages/queuer'
require 'archival_storage_ingest/workers/worker_pool'
require 'archival_storage_ingest/workers/fixity_compare_worker'
require 'archival_storage_ingest/workers/fixity_worker'
require 'archival_storage_ingest/workers/transfer_worker'

module ArchivalStorageIngest
  # Your code goes here...
  class IngestManager
    def initialize()
      default_config_path = '/cul/app/ingest/archival_storage/conf/settings.yaml';
      env_config_path = 'archival_storage_ingest_config'
      config_file = ENV[env_config_path]
      if config_file.nil?
        warn "#{env_config_path} env variable is not set, using default config file path #{default_config_path}"
        config_file = default_config_path;
      end
      
      if !File.exists?(config_file)
        raise "Configuration file #{config_file} does not exist!"
      end

      @config = config_file
      @poller = Poller::SQSPoller.new
      @queuer = Queuer::SQSQueuer.new
      @worker_pool = WorkerPool::CWorkerPool.new
    end

    def queue_ingest(ingest_config)
      msg = IngestMessage::SQSMessage.new
      @queuer.put_message(msg)
    end

    def start
      while true
        do_work
        sleep(30) # get this value from config
      end
    end

    def do_work
      process_finished_job()

      if !@worker_pool.is_available?
        # do nothing
        return
      end

      msg = @poller.get_message
      if msg.is_nil?
        # do nothing
        return
      end

      process_message(msg)
    end

    def process_finished_job
      @worker_pool.active.each do | worker |
        if worker.status == false
          ## it worked!
          result = worker.value
          ## do work
        elsif worker.status == nil
          ## it died unexpectedly
          ## move to error queue
        end
      end
      @worker_pool.clear_inactive_jobs
    end

    def process_message(msg)
      case msg.type
      when IngestMessage.TYPE_TRANSFER_S3
      when IngestMessage.TYPE_TRANSFER_SFS
      when IngestMessage.TYPE_FIXITY_S3
      when IngestMessage.TYPE_FIXITY_SFS
      when IngestMessage.TYPE_FIXITY_COMPARE
      else
        warn "Unknown message type: " + msg.type
      end
    end
  end
end
