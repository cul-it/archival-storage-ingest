require 'aws-sdk-sqs'
require 'archival_storage_ingest/messages/ingest_message'

# Poller implementations, currently supports SQS poller
module Poller
  # SQS poller implementation
  class SQSPoller
    def initialize(queue_name, logger)
      @sqs = Aws::SQS::Client.new
      @logger = logger
      @queue_name = queue_name
      @queue_url = @sqs.get_queue_url(queue_name: queue_name).queue_url
    end

    # http://ruby-doc.org/core-2.5.0/Hash.html
    # Hashes enumerate their values in the order that the corresponding keys were inserted.
    #
    # It will traverse the subscribed queues in order and return the fist valid message.
    def retrieve_single_message
      resp = @sqs.receive_message(queue_url: @queue_url,
                                  max_number_of_messages: 1)

      return nil if resp.messages.empty?

      m = resp.messages[0]
      @logger.debug('Poller successfully received message from SQS: ' + m.body)
      IngestMessage.to_sqs_message(m)
    end
  end
end
