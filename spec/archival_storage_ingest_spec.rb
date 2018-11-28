# frozen_string_literal: true

require 'rspec'
require 'rspec/mocks'
require 'spec_helper'
require 'archival_storage_ingest'
require 'archival_storage_ingest/messages/ingest_queue'
require 'archival_storage_ingest/messages/queues'
require 'json'

RSpec.describe ArchivalStorageIngest do # rubocop:disable BlockLength
  it 'has a version number' do
    expect(ArchivalStorageIngest::VERSION).not_to be nil
  end

  let(:queuer) do
    logger = spy('logger')
    IngestQueue::SQSQueuer.new(logger)
  end

  describe 'IngestQueuer' do
    let(:ingest_queuer) do
      ArchivalStorageIngest.configure do |config|
        config.queuer = queuer
      end
      ingest_queuer = ArchivalStorageIngest::IngestQueuer.new
      allow(ingest_queuer).to receive(:confirm_ingest) { true }
      ingest_queuer
    end

    context 'when queuing message' do
      it 'should send message to ingest queue' do
        allow(queuer).to receive(:put_message)
          .with(Queues::QUEUE_INGEST, anything).and_return(1) # doesn't matter what we return as we don't use it
        ingest_queuer.queue_ingest(ingest_id: 'test_id')
        expect(queuer).to have_received(:put_message).exactly(1).times
      end
    end
  end

  describe 'MessageMover' do # rubocop:disable BlockLength
    let(:message_mover) do
      ArchivalStorageIngest.configure do |config|
        config.queuer = queuer
      end
      ArchivalStorageIngest::MessageMover.new
    end

    let(:message_response) do
      resp = spy('body')
      allow(resp).to receive(:body) { { ingest_id: 'test' }.to_json }
      resp
    end

    context 'when moving message' do
      it 'should remove from source queue and add to target queue' do
        allow(queuer).to receive(:retrieve_single_message)
          .with(Queues::QUEUE_FIXITY_S3_IN_PROGRESS).and_return(message_response)
        allow(queuer).to receive(:delete_message)
          .with(anything, Queues::QUEUE_FIXITY_S3_IN_PROGRESS).and_return(1)
        allow(queuer).to receive(:put_message)
          .with(Queues::QUEUE_FIXITY_S3, anything).and_return(1)
        message_mover.move_message(source: Queues::QUEUE_FIXITY_S3_IN_PROGRESS,
                                   target: Queues::QUEUE_FIXITY_S3)
        expect(queuer).to have_received(:retrieve_single_message).exactly(1).times
        expect(queuer).to have_received(:delete_message).exactly(1).times
        expect(queuer).to have_received(:put_message).exactly(1).times
      end
    end
  end
end
