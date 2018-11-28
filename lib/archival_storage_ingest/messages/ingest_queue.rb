# frozen_string_literal: true

require 'aws-sdk-sqs'
require 'archival_storage_ingest/messages/ingest_message'

# Message queuer implementations, currently supports SQS
module IngestQueue
  # SQS message queuer implementation
  class SQSQueuer
    def initialize(logger)
      @known_queues = {}
      @logger = logger
      @sqs = Aws::SQS::Client.new
    end

    # rubocop: disable Metrics/MethodLength
    def put_message(queue_name, msg)
      queue_url = get_queue_url(queue_name)
      send_message_result = @sqs.send_message(
        queue_url: queue_url,
        message_body: msg.to_json,
        message_attributes: {
          ingest_id: {
            string_value: msg.ingest_id,
            data_type: 'String'
          }
        }
      )
      @logger.debug("Queuer successfully sent message to SQS with message id #{send_message_result.message_id}")

      send_message_result
    end

    # rubocop: enable Metrics/MethodLength

    def retrieve_single_message(queue_name)
      queue_url = get_queue_url(queue_name)
      resp = @sqs.receive_message(queue_url: queue_url,
                                  max_number_of_messages: 1)

      return nil if resp.messages.empty?

      m = resp.messages[0]
      @logger.debug("Queuer successfully received message from SQS: #{m.body}")
      m
    end

    def get_queue_url(queue_name)
      if @known_queues[queue_name].nil?
        queue_url = @sqs.get_queue_url(queue_name: queue_name).queue_url
        @known_queues[queue_name] = queue_url
      end

      @known_queues[queue_name]
    end

    # This method expects to find original SQS message in msg as original_msg.
    # It must be able to get receipt_handle from SQS get message.
    # That is the only way to delete a message in SQS.
    #
    # Currently, delete message is in queuer for convenience.
    # Move it to another place if needed.
    def delete_message(msg, queue_name)
      @sqs.delete_message(
        queue_url: get_queue_url(queue_name),
        receipt_handle: msg.original_msg.receipt_handle
      )
    end
  end

  class SQSQueue
    attr_reader :queue_name

    def initialize(queue_name, queuer)
      @queuer = queuer
      @queue_name = queue_name
    end

    def send_message(msg)
      @queuer.put_message(queue_name, msg)
    end

    def retrieve_message
      raw_message = @queuer.retrieve_single_message(queue_name)
      return nil if raw_message.nil?

      IngestMessage.convert_sqs_response(raw_message)
    end

    def delete_message(msg)
      @queuer.delete_message(msg, queue_name)
    end
  end
end
