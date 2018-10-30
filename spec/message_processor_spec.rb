# frozen_string_literal: true

require 'rspec'
require 'rspec/mocks'

RSpec.describe 'Message processor' do # rubocop:disable Metrics/BlockLength
  before(:each) do
    @queuer = spy('Queuer')
    @logger = spy('Logger')
    @processor = MessageProcessor::SQSMessageProcessor.new(@queuer, @logger)
  end

  context 'when processing ingest message' do
    before(:each) do
      msg = IngestMessage::SQSMessage.new(ingest_id: 'ingest message test', type: IngestMessage::TYPE_INGEST)
      @processor.process_message(msg)
    end

    it 'gets sent to the S3 Transfer queue' do
      expect(@queuer).to have_received(:put_message)
        .with(Queues::QUEUE_TRANSFER_S3, have_attributes(type: IngestMessage::TYPE_TRANSFER_S3)).once
    end

    it 'gets sent to the SFS Transfer queue' do
      expect(@queuer).to have_received(:put_message)
        .with(Queues::QUEUE_TRANSFER_SFS, have_attributes(type: IngestMessage::TYPE_TRANSFER_SFS)).once
    end

    it 'gets sent to only two queues' do
      expect(@queuer).to have_received(:put_message).twice
    end

    it 'logs the transfers' do
      expect(@logger).to have_received(:info).twice
    end
  end

  context 'when processing S3 transfer message' do
    before(:each) do
      msg = IngestMessage::SQSMessage.new(ingest_id: 'ingest message test', type: IngestMessage::TYPE_TRANSFER_S3)
      @processor.process_message(msg)
    end

    it 'gets sent to the S3 fixity queue' do
      expect(@queuer).to have_received(:put_message)
        .with(Queues::QUEUE_FIXITY_S3, have_attributes(type: IngestMessage::TYPE_FIXITY_S3)).once
    end

    it 'gets sent to only one queue' do
      expect(@queuer).to have_received(:put_message).once
    end

    it 'logs the transfers' do
      expect(@logger).to have_received(:info).twice
    end
  end

  context 'when processing SFS transfer message' do
    before(:each) do
      msg = IngestMessage::SQSMessage.new(ingest_id: 'ingest message test', type: IngestMessage::TYPE_TRANSFER_SFS)
      @processor.process_message(msg)
    end

    it 'gets sent to the S3 fixity queue' do
      expect(@queuer).to have_received(:put_message)
        .with(Queues::QUEUE_FIXITY_SFS, have_attributes(type: IngestMessage::TYPE_FIXITY_SFS)).once
    end

    it 'gets sent to only one queue' do
      expect(@queuer).to have_received(:put_message).once
    end

    it 'logs the transfers' do
      expect(@logger).to have_received(:info).twice
    end
  end
end
