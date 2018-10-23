# frozen_string_literal: true

require 'archival_storage_ingest/version'
require 'archival_storage_ingest/exception/ingest_exception'
require 'archival_storage_ingest/logs/archival_storage_ingest_logger'
require 'archival_storage_ingest/messages/ingest_message'
require 'archival_storage_ingest/messages/poller'
require 'archival_storage_ingest/messages/ingest_queue'
require 'archival_storage_ingest/messages/queues'
require 'archival_storage_ingest/messages/message_processor'
require 'archival_storage_ingest/workers/fixity_compare_worker'
require 'archival_storage_ingest/workers/fixity_worker'
require 'archival_storage_ingest/workers/transfer_worker'
require 'yaml'
require 'aws-sdk-sqs'

# Main archival storage ingest server module
module ArchivalStorageIngest
  COMMAND_SERVER_START = 'start'
  COMMAND_SERVER_STATUS = 'status'
  COMMAND_SERVER_STOP = 'stop'

  class Configuration
    attr_accessor :subscribed_queue_name, :in_progress_queue_name, :log_path, :debug
    attr_accessor :message_queue_name, :worker, :dest_queue_names

    attr_writer :msg_q, :dest_qs, :wip_q

    # for use in tests
    attr_writer :logger, :queuer

    def logger
      @logger ||= ArchivalStorageIngestLogger.get_file_logger(self)
    end

    def queuer
      @queuer ||= IngestQueue::SQSQueuer.new(logger)
    end

    def msg_q
      @msg_q ||= IngestQueue::SQSQueue.new(message_queue_name, queuer)
    end

    def dest_qs
      @dest_qs ||= dest_queue_names.each {|qn| IngestQueue::SQSQueue.new(qn, queuer)}
    end

    def wip_q
      @wip_q ||= IngestQueue::SQSQueue.new(in_progress_queue_name, queuer)
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

    def initialize
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

    def start_server
      initialize_server

      begin
        do_work
      rescue IngestException => ex
        notify_and_quit(ex)
      end
    end

    def notify_and_quit(exception)
      # notify admins!
      @logger.fatal(exception)
      exit(0)
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
      # work is to get a message from msg_q,
      # process it, and pass it along to the next queue

      check_wip

      msg = msg_q.retrieve_message
      return if msg.nil?

      @logger.info("Message received: #{msg}")

      move_msg_to_wip(msg)

      worker.work(msg)

      dest_qs.each do |queue|
        queue.send_message(msg)
      end

      remove_wip_msg
    end

    def check_wip
      msg = @wip_q.retrieve_message
      raise IngestException unless msg.nil?
    end

    def move_msg_to_wip(msg)
      @wip_q.send_message(msg)
      @msg_q.delete_message(msg)
    end

    def remove_wip_msg
      msg = @wip_q.retrieve_message
      # report error if this in nil?
      @wip_q.delete_message(msg)
    end

    # private
    #
    # def load_configuration
    #   default_config_path = '/cul/app/archival_storage_ingest/conf/queue_ingest.yaml'
    #   env_config_path = 'archival_storage_ingest_config'
    #   config_file = ENV[env_config_path]
    #   if config_file.nil?
    #     warn "#{env_config_path} env variable is not set, using default config file path #{default_config_path}"
    #     config_file = default_config_path
    #   end
    #
    #   raise "Configuration file #{config_file} does not exist!" unless File.exist?(config_file)
    #
    #   @configuration = YAML.load_file(config_file)
    # end
  end
end
