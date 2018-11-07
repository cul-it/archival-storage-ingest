# frozen_string_literal: true

require 'archival_storage_ingest/version'
require 'archival_storage_ingest/exception/ingest_exception'
require 'archival_storage_ingest/logs/archival_storage_ingest_logger'
require 'archival_storage_ingest/messages/ingest_message'
require 'archival_storage_ingest/messages/poller'
require 'archival_storage_ingest/messages/ingest_queue'
require 'archival_storage_ingest/messages/queues'
require 'archival_storage_ingest/workers/fixity_compare_worker'
require 'archival_storage_ingest/workers/fixity_worker'
require 'archival_storage_ingest/workers/transfer_worker'
require 'archival_storage_ingest/s3/s3_manager'
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
    attr_writer :s3_bucket, :s3_manager, :dry_run

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
      @dest_qs ||= dest_queue_names.each { |qn| IngestQueue::SQSQueue.new(qn, queuer) }
    end

    def wip_q
      @wip_q ||= IngestQueue::SQSQueue.new(in_progress_queue_name, queuer)
    end

    def s3_bucket
      @s3_bucket ||= 's3-cular'
    end
    def s3_manager
      @s3_manager ||= S3Manager.new(s3_bucket)
    end
    def dry_run
      @dry_run ||= false
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
      @msg_q = ArchivalStorageIngest.configuration.msg_q
      @wip_q = ArchivalStorageIngest.configuration.wip_q
      @dest_qs = ArchivalStorageIngest.configuration.dest_qs
      @worker = ArchivalStorageIngest.configuration.worker

      @state = 'uninitialized'
    end

    def queue_ingest(ingest_config)
      return unless confirm_ingest(ingest_config)

      msg = IngestMessage::SQSMessage.new(
        ingest_id: SecureRandom.uuid,
        depositor: config['depositor'],
        collection: config['collection'],
        data_path: config['data_path'],
        dest_path: config['dest_path']
      )
      @queuer.put_message(Queues::QUEUE_INGEST, msg)
    end

    def confirm_ingest(ingest_config)
      puts "Depositor: #{ingest_config['depositor']}"
      puts "Collection: #{ingest_config['collection']}"
      puts "Data Path: #{ingest_config['data_path']}"
      puts "Destination Path: #{ingest_config['dest_path']}"
      puts 'Queue ingest? (Y/N)'
      input = gets.chomp
      'y'.casecmp(input).zero?
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

      status = worker.work(msg)

      dest_qs.each do |queue|
        queue.send_message(msg)
      end if status

      remove_wip_msg
    end

    def check_wip
      msg = @wip_q.retrieve_message
      raise IngestException unless msg.nil?
    end

    def move_msg_to_wip(msg)
      @wip_q.send_message(msg)
      @msg_q.delete_message(msg, subscribed_queue_name)
    end

    def remove_wip_msg
      msg = @wip_q.retrieve_message
      # report error if this in nil?
      @wip_q.delete_message(msg, in_progress_queue_name)
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
