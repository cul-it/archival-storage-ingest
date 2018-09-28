require 'aws-sdk-sqs'

# Message queuer implementations, currently supports SQS
module Queuer
  # SQS message queuer implementation
  class SQSQueuer
    def initialize
      @known_queues = {}
    end

    def put_message(queue_name, msg)
      json_msg = msg.to_json
      sqs = Aws::SQS::Client.new
      if @known_queues[queue_name].nil?
        queue_url = sqs.get_queue_url(queue_name: queue_name).queue_url
        @known_queues[queue_name] = queue_url
      end
      return sqs.send_message({
        queue_url: @known_queues[queue_name],
        message_body: json_msg,
        message_attributes: {
          "ingest_id" => {
            string_value: msg.ingest_id,
            data_type: "String"
          }
        }
      })
    end
  end
end
