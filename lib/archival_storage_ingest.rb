# frozen_string_literal: true

require 'archival_storage_ingest/version'
require 'archival_storage_ingest/exception/ingest_exception'
require 'archival_storage_ingest/ingest_utils/ingest_utils'
require 'archival_storage_ingest/logs/archival_storage_ingest_logger'
require 'archival_storage_ingest/manifests/manifests'
require 'archival_storage_ingest/messages/ingest_message'
require 'archival_storage_ingest/messages/ingest_queue'
require 'archival_storage_ingest/messages/queues'
require 'archival_storage_ingest/s3/s3_manager'
require 'archival_storage_ingest/ticket/ticket_handler'
require 'archival_storage_ingest/ticket/issue_tracker'
require 'forwardable'
require 'time'

# Main archival storage ingest server module
module ArchivalStorageIngest
  DEFAULT_POLLING_INTERVAL = 60
  WIP_REMOVAL_WAIT_TIME = 10
  STAGE_PROD = 'prod'
  STAGE_DEV = 'dev'
  STAGE_SANDBOX = 'sandbox'
  def self.valid_stage?(stage)
    [STAGE_PROD, STAGE_DEV, STAGE_SANDBOX].include?(stage)
  end

  class Configuration
    attr_accessor :message_queue_name, :in_progress_queue_name, :log_path, :debug, :worker, :dest_queue_names, :develop,
                  :inhibit_file, :global_inhibit_file, :stage
    # Only set log_queue/issue_logger in test!
    attr_writer :msg_q, :dest_qs, :wip_q, :s3_bucket, :s3_manager, :dry_run, :polling_interval, :wip_removal_wait_time,
                :logger, :queuer, :log_queue, :issue_logger

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

    def log_queue
      @log_queue ||= IngestQueue::SQSQueue.new(Queues.resolve_fifo_queue_name(queue: Queues::QUEUE_JIRA, stage: stage), queuer)
    end

    def issue_logger
      @issue_logger ||= TicketHandler::LogTracker.new(queue: log_queue, worker: worker.name)
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
  class IngestManager # rubocop:disable Metrics/ClassLength
    extend Forwardable

    def initialize
      @configuration = ArchivalStorageIngest.configuration
      @issue_logger = @configuration.issue_logger
    end

    def_delegators :@configuration, :logger, :msg_q, :wip_q, :dest_qs, :wip_removal_wait_time,
                   :worker, :polling_interval, :inhibit_file, :global_inhibit_file, :develop, :debug

    def_delegators :@issue_logger, :notify_worker_started, :notify_worker_completed,
                   :notify_worker_skipped, :notify_worker_error, :notify_error

    def start_server
      if develop
        run_dev_server
      else
        run_server
      end
    end

    def run_server
      logger.debug("#{worker.name} server started") if debug
      loop do
        sleep(polling_interval)

        shutdown if shutdown?

        do_work
      end
    end

    def run_dev_server
      puts "S3 bucket: #{@configuration.s3_bucket}"
      puts "Message Queue Name: #{@configuration.message_queue_name}"
      puts "In Progress Queue Name: #{@configuration.in_progress_queue_name}"
      puts "Destination Queue Names: #{@configuration.dest_queue_names}"
      puts 'Run? (Y/N)'
      do_work if 'y'.casecmp(gets.chomp).zero?
    end

    def shutdown
      logger.info 'Gracefully shutting down'
      exit 0
    end

    def shutdown?
      File.exist?(inhibit_file) || File.exist?(global_inhibit_file)
    end

    def notify_and_quit(exception, ingest_msg)
      logger.fatal(exception)

      error_msg = "#{exception}\n\n#{exception.backtrace.join("\n")}"

      if ingest_msg.nil?
        notify_error(error_msg)
      else
        notify_worker_error(ingest_msg: ingest_msg, error_msg: error_msg)
      end

      exit(0)
    end

    # To test do_work, I need to pass in the queues, logger, and worker for it to use
    #
    # do_work processes a single message from the input queue.
    #
    # logger.info appears to trigger ABC (Assignment Branch Condition) rubocop error.
    #
    # rubocop:disable Metrics/MethodLength
    def do_work
      # work is to get a message from msg_q,
      # process it, and pass it along to the next queue

      msg = nil
      begin
        check_wip

        return if (msg = msg_q.retrieve_message).nil?

        logger.info("Received #{msg.to_json}")

        move_msg_to_wip(msg)

        notify_worker_started(msg)

        status = _do_work_and_notify(msg)

        remove_wip_msg

        logger.info("#{status} #{msg.job_id}")
      rescue IngestException => e
        notify_and_quit(e, msg)
      end
    end
    # rubocop:enable Metrics/MethodLength

    def _do_work_and_notify(msg)
      go_to_next_queue = worker.work(msg)
      if go_to_next_queue
        send_next_message(msg)
        status = 'Completed'
        notify_worker_completed(msg)
      else
        status = 'Skipped'
        notify_worker_skipped(msg)
      end

      status
    end

    # Currently, when we detect wip message, we leave error message to the responsible jira ticket as well as
    # create new jira ticket about the error.
    # Do we need both? Can we remove the latter?
    def check_wip
      wip_msg = wip_q.retrieve_message
      return if wip_msg.nil?

      notify_worker_error(ingest_msg: wip_msg, error_msg: 'Incomplete work in progress detected.')
      raise IngestException, "Incomplete work in progress for ingest #{wip_msg.job_id} detected."
    end

    def move_msg_to_wip(msg)
      wip_q.send_message(msg)
      msg_q.delete_message(msg)
    end

    # Make this function wait 10 seconds before deletion.
    # The message is not viewable immediately after it is sent.
    # If the work is completed very quickly, by the time the code
    # reaches here, the message may not be available, yet.
    # Waiting for 10 seconds will ensure we get the message.
    def remove_wip_msg
      msg = nil
      3.times do
        msg = retrieve_wip_msg
        break if msg
      end

      raise IngestException, 'Failed to retrieve Work In Progress message.' unless msg

      wip_q.delete_message(msg)
    end

    def retrieve_wip_msg
      sleep wip_removal_wait_time
      wip_q.retrieve_message
    end

    def send_next_message(msg)
      dest_qs.each do |queue|
        queue.send_message(msg)
      end
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
