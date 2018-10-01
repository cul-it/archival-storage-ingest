require 'aws-sdk-sqs'
require 'archival_storage_ingest/messages/ingest_message'

# Poller implementations, currently supports SQS poller
module Poller
  # SQS poller implementation
  class SQSPoller
    def initialize(subscribed_queues, logger)
      @subscribed_queues = subscribed_queues
      @logger = logger
    end

    # http://ruby-doc.org/core-2.5.0/Hash.html
    # Hashes enumerate their values in the order that the corresponding keys were inserted.
    # It will traverse list of subscribed queues in the order defined in the configuration
    # until a valid message is retrieved.
    def get_message
      sqs = Aws::SQS::Client.new

      @subscribed_queues.each do |queue_name, queue_url|
        resp = sqs.receive_message(
          queue_url: queue_url,
          max_number_of_messages: 1)

        if !resp.messages.empty?
          resp.messages.each do |m|
            @logger.debug('Poller successfully received message from SQS: ' + m.body)
            return IngestMessage.to_sqs_message(m.body)
          end
        end
      end

      @logger.debug('Poller received no message from SQS')
      nil
    end
  end
end
