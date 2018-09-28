require 'archival_storage_ingest/messages/ingest_message'

# Message processor implementation
module MessageProcessor
  # SQS message processor
  class SQSMessageProcessor
    def initialize(queuer)
      @queuer = queuer
    end

    def process_message(msg)
      case msg.type
      when IngestMessage::TYPE_INGEST
        puts 'ingest_message.rb:14 Message ' + IngestMessage::TYPE_INGEST + ' received!'
      when IngestMessage::TYPE_TRANSFER_S3
        puts 'ingest_message.rb:16 Message ' + IngestMessage::TYPE_TRANSFER_S3 + ' received!'
      when IngestMessage::TYPE_TRANSFER_SFS
        puts 'ingest_message.rb:18 Message ' + IngestMessage::TYPE_TRANSFER_SFS + ' received!'
      when IngestMessage::TYPE_FIXITY_S3
        puts 'ingest_message.rb:20 Message ' + IngestMessage::TYPE_FIXITY_S3 + ' received!'
      when IngestMessage::TYPE_FIXITY_SFS
        puts 'ingest_message.rb:22 Message ' + IngestMessage::TYPE_FIXITY_SFS + ' received!'
      when IngestMessage::TYPE_FIXITY_COMPARE
        puts 'ingest_message.rb:24 Message ' + IngestMessage::TYPE_FIXITY_COMPARE + ' received!'
      else
        warn 'Unknown message type: ' + msg.type
      end
      puts 'ingest_message.rb:28 ' + msg.inspect
    end
  end
end
