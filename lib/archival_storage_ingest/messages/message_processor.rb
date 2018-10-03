require 'archival_storage_ingest/messages/ingest_message'

# Message processor implementation
module MessageProcessor
  # SQS message processor
  class SQSMessageProcessor
    def initialize(queuer, logger)
      @queuer = queuer
      @logger = logger
    end


    def process_message(msg)
      @logger.info('Received ingest message ' + msg.to_json)

      case msg.type
      when IngestMessage::TYPE_INGEST
        process_ingest(msg)
      when IngestMessage::TYPE_TRANSFER_S3
        @logger.info('Invoke transfer S3 worker')

      when IngestMessage::TYPE_TRANSFER_SFS
        @logger.info('Invoke transfer SFS worker')
      when IngestMessage::TYPE_FIXITY_S3
        @logger.info('Invoke fixity s3 worker')
      when IngestMessage::TYPE_FIXITY_SFS
        @logger.info('Invoke fixity sfs worker')
      when IngestMessage::TYPE_FIXITY_COMPARE
        @logger.info('Invoke fixity compare worker')
      else
        @logger.info('Invalid message received, doing nothing')
      end
    rescue StandardError => e # TODO: flesh out error handling
      puts e.message
      puts e.backtrace.inspect
      @queuer.put_message(Queues::QUEUE_ERROR, msg)
    else # TODO: figure out how to delete message.
      # @queuer.delete_message(msg.queue, msg)
    end

    private

    def process_ingest(msg)
      @logger.info('Put transfer s3 and sfs messages')

      send_message(msg, IngestMessage::TYPE_TRANSFER_S3)
      send_message(msg, IngestMessage::TYPE_TRANSFER_SFS)

    end

    def send_message(msg, type)
      msg_s3 = IngestMessage::SQSMessage.new(ingest_id: msg.ingest_id, type: type)
      @queuer.put_message(Queues::TYPE2QUEUE[type], msg_s3)
    end
  end
end
