# frozen_string_literal: true

require 'archival_storage_ingest/messages/ingest_queue'
require 'archival_storage_ingest/messages/queues'
require 'archival_storage_ingest/ticket/ticket_handler'
require 'forwardable'

class DeadLetterMonitor
  extend Forwardable

  attr_reader :dead_letter_queues, :name

  def_delegators :@configuration, :queuer, :ticket_handler

  def initialize(dead_letter_queues)
    @configuration = ArchivalStorageIngest.configuration
    @dead_letter_queues = dead_letter_queues
    @name = 'Dead Letter Queue Monitor'
  end

  def check_dead_letter_queues
    dead_letter_queues.each do |dead_letter_queue|
      dead_letter_message = check_dead_letter_queue(dead_letter_queue)
      next if dead_letter_message.nil?

      notify_dead_letter_message(dead_letter_queue: dead_letter_queue,
                                 dead_letter_message: dead_letter_message)
    end
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
end
