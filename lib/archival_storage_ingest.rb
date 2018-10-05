require 'archival_storage_ingest/version'
require 'archival_storage_ingest/logs/archival_storage_ingest_logger'
require 'archival_storage_ingest/messages/ingest_message'
require 'archival_storage_ingest/messages/poller'
require 'archival_storage_ingest/messages/queuer'
require 'archival_storage_ingest/messages/queues'
require 'archival_storage_ingest/messages/message_processor'
require 'archival_storage_ingest/workers/worker_pool'
require 'archival_storage_ingest/workers/fixity_compare_worker'
require 'archival_storage_ingest/workers/fixity_worker'
require 'archival_storage_ingest/workers/transfer_worker'
require 'yaml'
require 'aws-sdk-sqs'

# Main archival storage ingest server module
module ArchivalStorageIngest
  COMMAND_SERVER_START = 'start'.freeze
  COMMAND_SERVER_STATUS = 'status'.freeze
  COMMAND_SERVER_STOP = 'stop'.freeze

  # Ingest manager to either start the server or queue new ingest.
  class IngestManager
    def initialize
      load_configuration
      @logger = ArchivalStorageIngestLogger.get_file_logger(@config)
      @queuer = Queuer::SQSQueuer.new(@logger)
    end

    def queue_ingest(_ingest_config)
      msg = IngestMessage::SQSMessage.new(
        ingest_id: SecureRandom.uuid,
        type: IngestMessage::TYPE_INGEST
      )
      @queuer.put_message(Queues::QUEUE_INGEST, msg)
    end

    def initialize_server
      @poller = Poller::SQSPoller.new(@config['subscribed_queue'], @logger)
      @worker_pool = WorkerPool::CWorkerPool.new
      @message_processor = MessageProcessor::SQSMessageProcessor.new(@queuer, @logger)
    end

    def do_work
      # process_finished_job()

      # if !@worker_pool.is_available?
      #   # do nothing
      #   return
      # end

      msg = @poller.retrieve_single_message
      return if msg.nil?

      @message_processor.process_message(msg)
    end

    def process_finished_job
      @worker_pool.active.each do |worker|
        if !worker.status
          ## it worked!
          result = worker.value
          ## do work
        elsif worker.status.nil?
          ## it died unexpectedly
          ## move to error queue
        end
      end
      @worker_pool.clear_inactive_jobs
    end

    def start_server
      initialize_server

      begin # while true
        do_work
        # sleep(30) # get this value from config
      end
    end

    private

    def load_configuration
      default_config_path = '/cul/app/archival_storage_ingest/conf/queue_ingest.yaml'
      env_config_path = 'archival_storage_ingest_config'
      config_file = ENV[env_config_path]
      if config_file.nil?
        warn "#{env_config_path} env variable is not set, using default config file path #{default_config_path}"
        config_file = default_config_path
      end

      raise "Configuration file #{config_file} does not exist!" unless File.exist?(config_file)

      @config = YAML.load_file(config_file)
    end
  end
end
