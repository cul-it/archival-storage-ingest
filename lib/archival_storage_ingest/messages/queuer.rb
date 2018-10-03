require 'aws-sdk-sqs'

# Message queuer implementations, currently supports SQS
module Queuer
  # SQS message queuer implementation
  class SQSQueuer
    def initialize(logger)
      @known_queues = {}
      @logger = logger
      @sqs = Aws::SQS::Client.new
    end

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
      @logger.debug('Queuer successfully sent message to SQS with message id ' + send_message_result.message_id)

      send_message_result
    end

    def get_queue_url(queue_name)
      if @known_queues[queue_name].nil?
        queue_url = @sqs.get_queue_url(queue_name: queue_name).queue_url
        @known_queues[queue_name] = queue_url
      end

      @known_queues[queue_name]
    end
  end
end
