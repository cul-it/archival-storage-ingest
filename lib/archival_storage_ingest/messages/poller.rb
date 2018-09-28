require 'aws-sdk-sqs'
require 'archival_storage_ingest/messages/ingest_message'

# Poller implementations, currently supports SQS poller
module Poller
  # SQS poller implementation
  class SQSPoller
    def initialize(subscribed_queues)
      @subscribed_queues = subscribed_queues
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
            return IngestMessage::to_sqs_message(m)
          end
        end
      end
    end
  end
end
