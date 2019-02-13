# frozen_string_literal: true

require 'archival_storage_ingest/version'
require 'archival_storage_ingest/exception/ingest_exception'
require 'archival_storage_ingest/logs/archival_storage_ingest_logger'
require 'archival_storage_ingest/messages/ingest_message'
require 'archival_storage_ingest/messages/ingest_queue'
require 'archival_storage_ingest/messages/queues'
require 'archival_storage_ingest/s3/s3_manager'

# Main archival storage ingest server module
module ArchivalStorageIngest
  DEFAULT_POLLING_INTERVAL = 60
  WIP_REMOVAL_WAIT_TIME = 10

  class Configuration
    attr_accessor :message_queue_name, :in_progress_queue_name, :log_path, :debug
    attr_accessor :worker, :dest_queue_names
    attr_accessor :inhibit_file, :global_inhibit_file

    attr_writer :msg_q, :dest_qs, :wip_q

    attr_writer :s3_bucket, :s3_manager, :dry_run, :polling_interval, :wip_removal_wait_time

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
      @dest_qs ||= dest_queue_names.map { |qn| IngestQueue::SQSQueue.new(qn, queuer) }
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

    def polling_interval
      @polling_interval ||= DEFAULT_POLLING_INTERVAL
    end

    def wip_removal_wait_time
      @wip_removal_wait_time ||= WIP_REMOVAL_WAIT_TIME
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
      @configuration = ArchivalStorageIngest.configuration
      @logger = @configuration.logger
      @msg_q = @configuration.msg_q
      @wip_q = @configuration.wip_q
      @wip_wait_time = @configuration.wip_removal_wait_time
      @dest_qs = @configuration.dest_qs
      @worker = @configuration.worker
      @polling_interval = @configuration.polling_interval

      @state = 'uninitialized'
    end

    def start_server
      initialize_server

      loop do
        begin
          sleep(@polling_interval)

          shutdown if shutdown?

          do_work
        rescue IngestException => ex
          notify_and_quit(ex)
        end
      end
    end

    def shutdown
      @logger.info 'Gracefully shutting down'
      exit 0
    end

    def shutdown?
      File.exist?(@configuration.inhibit_file) || File.exist?(@configuration.global_inhibit_file)
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
    #
    # do_work processes a single message from the input queue.
    #
    def do_work
      # work is to get a message from msg_q,
      # process it, and pass it along to the next queue

      check_wip

      return if (msg = @msg_q.retrieve_message).nil?

      @logger.info("Message received: #{msg.to_json}")

      move_msg_to_wip(msg)

      send_next_message(msg) if @worker.work(msg)

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

    # Make this function wait 10 seconds before deletion.
    # The message is not viewable immediately after it is sent.
    # If the work is completed very quickly, by the time the code
    # reaches here, the message may not be available, yet.
    # Waiting for 10 seconds will ensure we get the message.
    def remove_wip_msg
      sleep @wip_wait_time
      msg = @wip_q.retrieve_message
      # report error if this in nil?
      @wip_q.delete_message(msg)
    end

    def send_next_message(msg)
      @dest_qs.each do |queue|
        queue.send_message(msg)
      end
    end
  end

  class IngestQueuer
    def initialize
      @queuer = ArchivalStorageIngest.configuration.queuer
    end

    def queue_ingest(ingest_config)
      return unless confirm_ingest(ingest_config)

      msg = IngestMessage::SQSMessage.new(
        ingest_id: SecureRandom.uuid,
        depositor: ingest_config['depositor'],
        collection: ingest_config['collection'],
        data_path: ingest_config['data_path'],
        dest_path: ingest_config['dest_path'],
        ingest_manifest: ingest_config['ingest_manifest']
      )
      @queuer.put_message(Queues::QUEUE_INGEST, msg)
    end

    def confirm_ingest(ingest_config)
      puts "Depositor: #{ingest_config['depositor']}"
      puts "Collection: #{ingest_config['collection']}"
      puts "Data Path: #{ingest_config['data_path']}"
      puts "Destination Path: #{ingest_config['dest_path']}"
      puts "Ingest Manifest: #{ingest_config['ingest_manifest']}"
      puts 'Queue ingest? (Y/N)'
      'y'.casecmp(gets.chomp).zero?
    end
  end

  class MessageMover
    def initialize
      @queuer = ArchivalStorageIngest.configuration.queuer
    end

    def move_message(conf)
      raise '-s and -t flags are required!' if conf[:source].nil? || conf[:target].nil?

      msg = remove_from_source_queue(conf[:source])

      target_q = IngestQueue::SQSQueue.new(conf[:target], @queuer)
      target_q.send_message(msg)
      puts "Sent message to the target queue #{conf[:target]}"

      puts 'Move message complete'
    end

    def remove_from_source_queue(source_queue_name)
      source_q = IngestQueue::SQSQueue.new(source_queue_name, @queuer)
      msg = source_q.retrieve_message
      puts "Message: #{msg}"

      source_q.delete_message(msg)
      puts "Removed message from the source queue #{source_queue_name}"

      msg
    end
  end
end
