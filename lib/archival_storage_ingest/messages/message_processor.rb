# frozen_string_literal: true

require 'archival_storage_ingest/messages/ingest_message'

# Message processor implementation
module MessageProcessor
  # SQS message processor
  class SQSMessageProcessor
    def initialize(queuer, logger)
      @queuer = queuer
      @logger = logger
    end

    # rubocop: disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
    def process_message(msg)
      @logger.info('Received ingest message ' + msg.to_json)

      case msg.type
      when IngestMessage::TYPE_INGEST
        process_ingest(msg)
      when IngestMessage::TYPE_TRANSFER_S3
        process_transfer_s3(msg)
      when IngestMessage::TYPE_TRANSFER_SFS
        process_transfer_sfs(msg)
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
      @logger.error("Could not process message ID:#{msg.ingest_id}")
      @logger.error(msg.to_json)
      @logger.error(e.message)
      @logger.error(e.backtrace.inspect)
      @queuer.put_message(Queues::QUEUE_ERROR, msg)
    else # TODO: figure out how to delete message.
      # @queuer.delete_message(msg.queue, msg)
    end

    # rubocop: enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength

    private

    def process_transfer_sfs(msg)
      @logger.info('Invoke transfer SFS worker')
      send_message(msg, IngestMessage::TYPE_FIXITY_SFS)
    end

    def process_transfer_s3(msg)
      @logger.info('Invoke transfer S3 worker')
      send_message(msg, IngestMessage::TYPE_FIXITY_S3)
    end

    def process_ingest(msg)
      @logger.info('Put transfer s3 and sfs messages')

      send_message(msg, IngestMessage::TYPE_TRANSFER_S3)
      send_message(msg, IngestMessage::TYPE_TRANSFER_SFS)
    end

    def send_message(msg, type)
      msg_s3 = IngestMessage::SQSMessage.new(ingest_id: msg.ingest_id, type: type)
      @queuer.put_message((IngestMessage.queue_name_from_work_type type), msg_s3)
    end
  end
end
