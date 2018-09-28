require 'archival_storage_ingest/messages/ingest_message'

module MessageProcessor
  class SQSMessageProcessor
    def initialize(queuer)
      @queuer = queuer
    end

    def process_message(msg)
      case msg.type
      when IngestMessage::TYPE_TRANSFER_S3
        puts "Message " + IngestMessage::TYPE_TRANSFER_S3  + " received!"
      when IngestMessage::TYPE_TRANSFER_SFS
        puts "Message " + IngestMessage::TYPE_TRANSFER_SFS  + " received!"
      when IngestMessage::TYPE_FIXITY_S3
        puts "Message " + IngestMessage::TYPE_FIXITY_S3  + " received!"
      when IngestMessage::TYPE_FIXITY_SFS
        puts "Message " + IngestMessage::TYPE_FIXITY_SFS  + " received!"
      when IngestMessage::TYPE_FIXITY_COMPARE
        puts "Message " + IngestMessage::TYPE_FIXITY_COMPARE  + " received!"
      else
        warn "Unknown message type: " + msg.type
      end
    end
  end
end
