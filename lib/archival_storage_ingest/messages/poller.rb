require 'aws-sdk-sqs'
require 'archival_storage_ingest/messages/ingest_message'

# Poller implementations, currently supports SQS poller
module Poller
  # SQS poller implementation
  class SQSPoller
    def initialize(subscribed_queues, logger)
      @subscribed_queues = subscribed_queues
      @logger = logger
      @sqs = Aws::SQS::Client.new
    end

    # http://ruby-doc.org/core-2.5.0/Hash.html
    # Hashes enumerate their values in the order that the corresponding keys were inserted.
    #
    # It will traverse the subscribed queues in order and return the fist valid message.
    def retrieve_single_message
      @subscribed_queues.each do |queue_name, queue_url|
        resp = @sqs.receive_message(queue_url: queue_url,
                                    max_number_of_messages: 1)

        next if resp.messages.empty?

        m = resp.messages[0]
        @logger.debug('Poller successfully received message from SQS: ' + m.body)
        return IngestMessage.to_sqs_message(m.body)
      end

      @logger.debug('Poller received no message from SQS')
      nil
    end
  end
end
