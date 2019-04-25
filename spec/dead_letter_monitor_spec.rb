# frozen_string_literal: true

require 'rspec'
require 'archival_storage_ingest/monitor/dead_letter_monitor'
require 'archival_storage_ingest/messages/ingest_queue'
require 'json'

RSpec.describe 'DeadLetterMonitor' do # rubocop:disable BlockLength
  let(:dead_letter_queue_name) { %w[dlq1 dlq2] }
  let(:dead_letter_message_hash) do
    {
      ingest_id: '21daed0d-f687-4fd1-94e2-0bc68c3c1f19',
      data_path: '/cul/app/archival_storage_ingest/data/source',
      dest_path: '/cul/app/archival_storage_ingest/data/target',
      depositor: 'test_depositor', "collection": 'test_collection',
      ingest_manifest: '/cul/app/archival_storage_ingest/ingest/test/manifest/ingest_manifest/test.json',
      ticket_id: 'CULAR-1937'
    }
  end
  let(:dead_letter_message) { JSON.generate(dead_letter_message_hash) }
  let(:queuer) do
    logger = spy('logger')
    sqs_queuer = IngestQueue::SQSQueuer.new(logger)

    sqs_response = spy('sqs_response')
    allow(sqs_response).to receive(:body) { dead_letter_message }
    allow(sqs_queuer).to receive(:retrieve_single_message).with(dead_letter_queue_name[0]) { sqs_response }
    allow(sqs_queuer).to receive(:retrieve_single_message).with(dead_letter_queue_name[1]) { nil }

    sqs_queuer
  end
  let(:ticket_handler) { spy('ticket_handler') }

  context 'when dead letter message is found' do
    it 'sends notification' do
      ArchivalStorageIngest.configure do |config|
        config.queuer = queuer
        config.ticket_handler = ticket_handler
      end
      dead_letter_monitor = DeadLetterMonitor.new(dead_letter_queue_name)

      dead_letter_message = dead_letter_monitor.check_dead_letter_queue(dead_letter_queue_name[0])
      expect(dead_letter_message.ingest_id).to eq(dead_letter_message_hash[:ingest_id])

      dead_letter_message = dead_letter_monitor.check_dead_letter_queue(dead_letter_queue_name[1])
      expect(dead_letter_message).to be_an_nil

      dead_letter_monitor.check_dead_letter_queues
      expect(ticket_handler).to have_received(:update_issue_tracker).once
    end
  end
end
