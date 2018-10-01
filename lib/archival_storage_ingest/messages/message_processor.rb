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
        @logger.info('Put transfer s3 and sfs messages')
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
  end
end
