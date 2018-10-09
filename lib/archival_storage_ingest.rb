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

  class Configuration
    attr_accessor :subscribed_queue_name, :in_progress_queue_name, :log_path, :debug
    attr_accessor :message_queue_name, :worker, :dest_queue_names

    attr_accessor :msg_q, :dest_qs, :wip_q

    # for use in tests
    attr_accessor :logger, :queuer

    def logger
      @logger ||= ArchivalStorageIngestLogger.get_file_logger(self)
    end

    def queuer
      @queuer ||= Queuer::SQSQueuer.new(logger)
    end

    def msg_q
      @msg_q ||= Queuer::SQSQueue.new(message_queue_name, queuer)
    end

    def dest_qs
      @dest_qs ||= dest_queue_names.each {|qn| Queuer::SQSQueue.new(qn, queuer)}
    end
  end

  class << self
    attr_writer :configuration
  end

  def self.configure
    yield(configuration)
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  # Ingest manager to either start the server or queue new ingest.
  class IngestManager
    attr_reader :state

    def initialize()

      @logger = ArchivalStorageIngest.configuration.logger
      @queuer = ArchivalStorageIngest.configuration.queuer

      @state = 'uninitialized'
    end

    def queue_ingest(_ingest_config)
      msg = IngestMessage::SQSMessage.new(
        ingest_id: SecureRandom.uuid,
        type: IngestMessage::TYPE_INGEST
      )
      @queuer.put_message(Queues::QUEUE_INGEST, msg)
    end

    def initialize_server

      @msg_q = ArchivalStorageIngest.configuration.msg_q
      @wip_q = ArchivalStorageIngest.configuration.wip_q
      @dest_qs = ArchivalStorageIngest.configuration.dest_qs
      @worker = ArchivalStorageIngest.configuration.worker
      @state = 'started'

    end

    # To test do_work, I need to pass in the queues, logger, and worker for it to use
    def do_work(msg_q: @msg_q, worker: @worker, dest_qs: @dest_qs)

      # work is to get a message from msgq,
      # process it, and pass it along to the next queue

      msg = msg_q.retrieve_message
      return if msg.nil?

      worker.work(msg)

      dest_qs.each do |queue|
        queue.send_message(msg)

      end
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

      @configuration = YAML.load_file(config_file)
    end
  end
end
