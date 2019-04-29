# frozen_string_literal: true

require 'archival_storage_ingest/messages/ingest_queue'
require 'archival_storage_ingest/messages/queues'
require 'archival_storage_ingest/ticket/ticket_handler'
require 'forwardable'
require 'mail'

class DeadLetterMonitor
  extend Forwardable

  attr_reader :dead_letter_queues, :name, :notify_list

  def_delegators :@configuration, :queuer, :ticket_handler

  DEFAULT_FROM = 'cular-jiramailer@cornell.edu'
  DEFAULT_TO = %w[sk274@cornell.edu bb233@cornell.edu].freeze
  OK_MSG = 'No dead letter message found'

  def initialize(dead_letter_queues:, notify_list: DEFAULT_TO)
    @configuration = ArchivalStorageIngest.configuration
    @dead_letter_queues = dead_letter_queues
    @name = 'Dead Letter Queue Monitor'
    @notify_list = notify_list
    Mail.defaults do
      delivery_method :sendmail
    end
  end

  def check_dead_letter_queues
    dead_letter_found = false
    dead_letter_queues.each do |dead_letter_queue|
      dead_letter_message = check_dead_letter_queue(dead_letter_queue)
      next if dead_letter_message.nil?

      notify_dead_letter_message(dead_letter_queue: dead_letter_queue,
                                 dead_letter_message: dead_letter_message)
      dead_letter_found = true
    end

    # if dead letter is found, developers would have been notified above.
    notify_admin_ok unless dead_letter_found
  end

  def check_dead_letter_queue(dead_letter_queue)
    sqs_queue = IngestQueue::SQSQueue.new(dead_letter_queue, queuer)
    sqs_queue.retrieve_message
  end

  def notify_dead_letter_message(dead_letter_queue:, dead_letter_message:)
    body = "#{Time.new}\n" \
           "#{name}\n" \
           "Depositor/Collection: #{dead_letter_message.depositor}/#{dead_letter_message.collection}\n" \
           "Ingest ID: #{dead_letter_message.ingest_id}\n" \
           "Status: Error\n\n#Dead letter message found on #{dead_letter_queue}."
    ticket_handler.update_issue_tracker(subject: dead_letter_message.ticket_id, body: body)
  end

  def notify_admin_ok
    notify_list.each do |admin|
      mail = Mail.new do
        subject OK_MSG
        body OK_MSG
      end
      # Why don't these work on constructor???
      mail.from(DEFAULT_FROM)
      mail.to(admin)
      mail.deliver
    end
  end
end
