require 'rspec'
require 'rspec/mocks'

RSpec.describe 'Message processor' do
  context 'when processing ingest message' do
    before(:each) do
      @queuer = spy('Queuer')
      @logger = spy('Logger')
      @processor = MessageProcessor::SQSMessageProcessor.new(@queuer, @logger)
    end

    msg = IngestMessage::SQSMessage.new(ingest_id: 'ingest message test', type: IngestMessage::TYPE_INGEST)

    it 'gets sent to the S3 Transfer queue' do
      @processor.process_message(msg)

      expect(@queuer).to have_received(:put_message)
                             .with(Queues::QUEUE_TRANSFER_S3,
                                   have_attributes(type: IngestMessage::TYPE_TRANSFER_S3)).once
    end

    it 'gets sent to the SFS Transfer queue' do
      @processor.process_message(msg)
      expect(@queuer).to have_received(:put_message)
                             .with(Queues::QUEUE_TRANSFER_SFS,
                                   have_attributes(type: IngestMessage::TYPE_TRANSFER_SFS)).once
    end
  end
end
