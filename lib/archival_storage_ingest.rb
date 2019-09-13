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
require 'forwardable'
require 'time'

# Main archival storage ingest server module
module ArchivalStorageIngest
  DEFAULT_POLLING_INTERVAL = 60
  WIP_REMOVAL_WAIT_TIME = 10

  class Configuration
    attr_accessor :message_queue_name, :in_progress_queue_name, :log_path, :debug
    attr_accessor :worker, :dest_queue_names, :develop
    attr_accessor :inhibit_file, :global_inhibit_file

    # Only set issue_tracker_helper in test!
    attr_writer :msg_q, :dest_qs, :wip_q, :ticket_handler, :issue_tracker_helper

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

    def ticket_handler
      @ticket_handler ||= TicketHandler::JiraHandler.new
    end

    def issue_tracker_helper
      @issue_tracker_helper ||= IssueTrackerHelper.new(worker_name: worker.name,
                                                       ticket_handler: ticket_handler)
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
    extend Forwardable

    def initialize
      @configuration = ArchivalStorageIngest.configuration
      @issue_tracker_helper = @configuration.issue_tracker_helper
    end

    def_delegators :@configuration, :logger, :msg_q, :wip_q, :dest_qs, :wip_removal_wait_time,
                   :worker, :polling_interval, :inhibit_file, :global_inhibit_file, :develop

    def_delegators :@issue_tracker_helper, :notify_worker_started, :notify_worker_completed,
                   :notify_worker_skipped, :notify_worker_error, :notify_error

    def start_server
      if develop
        run_dev_server
      else
        run_server
      end
    end

    def run_server
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

      error_msg = exception.to_s + "\n\n" + exception.backtrace.join("\n")

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
    # rubocop:disable Metrics/AbcSize
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

        logger.info("#{status} #{msg.ingest_id}")
      rescue IngestException => e
        notify_and_quit(e, msg)
      end
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/AbcSize

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

    def check_wip
      wip_msg = wip_q.retrieve_message
      return if wip_msg.nil?

      notify_worker_error(ingest_msg: wip_msg, error_msg: 'Incomplete work in progress detected.')
      raise IngestException, "Incomplete work in progress for ingest #{wip_msg.ingest_id} detected."
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
      sleep wip_removal_wait_time
      msg = wip_q.retrieve_message
      # report error if this is nil?
      wip_q.delete_message(msg)
    end

    def send_next_message(msg)
      dest_qs.each do |queue|
        queue.send_message(msg)
      end
    end
  end

  class IssueTrackerHelper
    attr_reader :worker_name, :ticket_handler

    def initialize(worker_name:, ticket_handler:)
      @worker_name = worker_name
      @ticket_handler = ticket_handler
    end

    # These will add a comment to an existing ticket.
    def notify_worker_started(ingest_msg)
      notify_status(ingest_msg: ingest_msg, status: 'Started')
    end

    def notify_worker_completed(ingest_msg)
      notify_status(ingest_msg: ingest_msg, status: 'Completed')
    end

    def notify_worker_skipped(ingest_msg)
      notify_status(ingest_msg: ingest_msg, status: 'Skipped')
    end

    def notify_worker_error(ingest_msg:, error_msg:)
      body = "#{Time.new}\n" \
             "#{worker_name}\n" \
             "Depositor/Collection: #{ingest_msg.depositor}/#{ingest_msg.collection}\n" \
             "Ingest ID: #{ingest_msg.ingest_id}\n" \
             "Status: Error\n\n#{error_msg}"
      ticket_handler.update_issue_tracker(subject: ingest_msg.ticket_id, body: body)
    end

    def notify_status(ingest_msg:, status:)
      body = "#{Time.new}\n" \
             "#{worker_name}\n" \
             "Depositor/Collection: #{ingest_msg.depositor}/#{ingest_msg.collection}\n" \
             "Ingest ID: #{ingest_msg.ingest_id}\n" \
             "Status: #{status}"
      ticket_handler.update_issue_tracker(subject: ingest_msg.ticket_id, body: body)
    end

    # This will create a new ticket.
    def notify_error(error_msg)
      subject = "#{worker_name} service has terminated due to fatal error."
      body = "#{Time.new}\n#{error_msg}"
      ticket_handler.update_issue_tracker(subject: subject, body: body)
    end
  end

  class IngestQueuer
    def initialize
      @configuration = ArchivalStorageIngest.configuration

      @queuer = @configuration.queuer
      @queue_name = @configuration.message_queue_name
      @ticket_handler = @configuration.ticket_handler
      @develop = @configuration.develop
    end

    def queue_ingest(ingest_config)
      input_checker = check_input(ingest_config)
      if input_checker.errors.size.positive?
        puts input_checker.errors
        return
      end

      return unless confirm_ingest(ingest_config, input_checker.ingest_manifest)

      ingest_msg = _queue_ingest(ingest_config)

      send_notification(ingest_msg)
    end

    def check_input(ingest_config)
      input_checker = InputChecker.new
      input_checker.check_input(ingest_config)
      input_checker
    end

    def send_notification(ingest_msg)
      body = "New ingest queued at #{Time.new}.\n" \
             "Depositor/Collection: #{ingest_msg.depositor}/#{ingest_msg.collection}\n" \
             "Ingest Info\n#{ingest_msg.to_pretty_json}"
      @ticket_handler.update_issue_tracker(subject: ingest_msg.ticket_id, body: body)
    end

    def _queue_ingest(ingest_config)
      msg = IngestMessage::SQSMessage.new(
        ingest_id: SecureRandom.uuid, ticket_id: ingest_config[:ticket_id],
        depositor: ingest_config[:depositor], collection: ingest_config[:collection],
        dest_path: ingest_config[:dest_path],
        ingest_manifest: ingest_config[:ingest_manifest]
      )
      @queuer.put_message(@queue_name, msg)
      msg
    end

    def confirm_ingest(ingest_config, ingest_manifest)
      puts "S3 bucket: #{@configuration.s3_bucket}"
      puts "Destination Queue: #{@queue_name}"
      print_config_settings(ingest_config)
      puts "Source path: #{ingest_manifest.packages[0].source_path}"
      puts 'Queue ingest? (Y/N)'
      'y'.casecmp(gets.chomp).zero?
    end

    def print_config_settings(ingest_config)
      ingest_config.keys.sort.each do |key|
        puts "#{key}: #{ingest_config[key]}"
      end
    end
  end

  class InputChecker
    attr_accessor :ingest_manifest, :errors
    def initialize
      @errors = []
    end

    def check_input(ingest_config)
      return false unless config_ok?(ingest_config)

      ingest_manifest_errors(ingest_config[:ingest_manifest])
    end

    def config_ok?(ingest_config)
      # if dest_path is blank, use empty string '' to avoid errors printing it
      dest_path = IngestUtils.if_empty(ingest_config[:dest_path], '')
      @errors << "dest_path '#{dest_path}' does not exist!" unless
        dest_path_ok?(dest_path)

      ingest_manifest = ingest_config[:ingest_manifest].to_s.strip
      @errors << "ingest_manifest #{ingest_manifest} does not exist!" unless
        File.exist?(ingest_manifest)

      @errors.size.zero?
    end

    def dest_path_ok?(dest_path)
      return true if File.exist?(dest_path)

      # We store data under /cul/data/archivalxx/DEPOSITOR/COLLECTION
      # If we can find up to archivalxx, we should be OK.
      # We may need to change this behavior when we adopt OCFL.
      without_collection = File.dirname(dest_path)
      without_depositor  = File.dirname(without_collection)

      # The most likely case for '.' is when dest_path is blank.
      return false if without_depositor == '.'

      File.exist?(without_depositor)
    end

    def ingest_manifest_errors(input_ingest_manifest)
      @ingest_manifest = Manifests.read_manifest(filename: input_ingest_manifest)
      @ingest_manifest.walk_packages do |package|
        @errors << "Source path for package #{package.package_id} is not valid!" unless
          File.exist?(package.source_path.to_s)
      end
      @errors.size.zero?
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
