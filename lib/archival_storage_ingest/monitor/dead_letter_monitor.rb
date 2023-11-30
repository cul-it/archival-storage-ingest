# frozen_string_literal: true

require 'archival_storage_ingest/messages/ingest_queue'
require 'archival_storage_ingest/messages/queues'
require 'forwardable'
# require 'mail'

class DeadLetterMonitor
  extend Forwardable

  attr_reader :dead_letter_queues, :name, :notify_list

  def_delegators :@configuration, :queuer, :issue_logger

  # DEFAULT_FROM = 'cular-jiramailer@cornell.edu'
  # DEFAULT_TO = %w[sk274@cornell.edu rld244@cornell.edu].freeze
  # OK_MSG = 'No dead letter message found'

  def initialize(dead_letter_queues:)
    @configuration = ArchivalStorageIngest.configuration
    @dead_letter_queues = dead_letter_queues
    @name = 'Dead Letter Queue Monitor'
    # @notify_list = notify_list
    # Mail.defaults do
    #   delivery_method :sendmail
    # end
  end

  def check_dead_letter_queues
    # dead_letter_found = false
    dead_letter_queues.each do |dead_letter_queue|
      dead_letter_message = check_dead_letter_queue(dead_letter_queue)
      next if dead_letter_message.nil?

      notify_dead_letter_message(dead_letter_queue:,
                                 dead_letter_message:)
      # dead_letter_found = true
    end

    # if dead letter is found, developers would have been notified above.
    # notify_admin_ok unless dead_letter_found
  end

  def check_dead_letter_queue(dead_letter_queue)
    sqs_queue = IngestQueue::SQSQueue.new(dead_letter_queue, queuer)
    sqs_queue.retrieve_message
  end

  def notify_dead_letter_message(dead_letter_queue:, dead_letter_message:)
    error_msg = "#Dead letter message found on #{dead_letter_queue}"
    dead_letter_message.worker = 'Dead letter monitor'
    issue_logger.notify_worker_error(ingest_msg: dead_letter_message, error_msg:)
  end

  # def notify_admin_ok
  #   notify_list.each do |admin|
  #     mail = Mail.new do
  #       subject OK_MSG
  #       body OK_MSG
  #     end
  #     # Why don't these work on constructor???
  #     mail.from(DEFAULT_FROM)
  #     mail.to(admin)
  #     mail.deliver
  #   end
  # end
end
