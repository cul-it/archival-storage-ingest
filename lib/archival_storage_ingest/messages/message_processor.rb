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
    end

    private

    def process_ingest(msg)
      @logger.info('Put transfer s3 and sfs messages')
      msg_s3 = SQSMessage.new(ingest_id: msg.ingest_id, type: TYPE_TRANSFER_S3)
      msg_sfs = SQSMessage.new(ingest_id: msg.ingest_id, type: TYPE_TRANSFER_SFS)

      @queuer.put_message(QUEUE_TRANSFER_S3, msg_s3)
      @queuer.put_message(QUEUE_TRANSFER_SFS, msg_sfs)
    end
  end
end
