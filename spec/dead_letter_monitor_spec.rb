# frozen_string_literal: true

require 'rspec'
require 'archival_storage_ingest/monitor/dead_letter_monitor'
require 'archival_storage_ingest/messages/ingest_queue'
require 'json'
# require 'mail'
# require 'mail/network/delivery_methods/test_mailer'

RSpec.describe 'DeadLetterMonitor' do # rubocop:disable Metrics/BlockLength
  let(:dead_letter_queue_name) { %w[dlq1 dlq2] }
  let(:dead_letter_message_hash) do
    {
      job_id: '21daed0d-f687-4fd1-94e2-0bc68c3c1f19',
      dest_path: '/cul/app/archival_storage_ingest/data/target',
      depositor: 'test_depositor', "collection": 'test_collection',
      ingest_manifest: '/cul/app/archival_storage_ingest/ingest/test/manifest/ingest_manifest/test.json',
      ticket_id: 'CULAR-1937'
    }
  end
  let(:queuer) do
    sqs_queuer = spy('sqs_queuer')
    sqs_response = spy('sqs_response')
    allow(sqs_response).to receive(:body) { JSON.generate(dead_letter_message_hash) }
    allow(sqs_queuer).to receive(:retrieve_single_message).with(dead_letter_queue_name[0]) { sqs_response }
    allow(sqs_queuer).to receive(:retrieve_single_message).with(dead_letter_queue_name[1]) { nil }
    sqs_queuer
  end

  context 'When dead letter message is found' do
    it 'Adds error message to Jira ticket' do
      issue_logger = spy('issue_logger')
      ArchivalStorageIngest.configure do |config|
        config.queuer = queuer
        config.issue_logger = issue_logger
      end
      dead_letter_monitor = DeadLetterMonitor.new(dead_letter_queues: dead_letter_queue_name)

      dead_letter_message = dead_letter_monitor.check_dead_letter_queue(dead_letter_queue_name[0])
      expect(dead_letter_message.job_id).to eq(dead_letter_message_hash[:job_id])

      dead_letter_message = dead_letter_monitor.check_dead_letter_queue(dead_letter_queue_name[1])
      expect(dead_letter_message).to be_an_nil

      # # Instantiate this lazy variable so next defaults section actually takes effect!
      # Mail.defaults do
      #   delivery_method :test
      # end
      # Mail::TestMailer.deliveries.clear

      dead_letter_monitor.check_dead_letter_queues
      expect(issue_logger).to have_received(:notify_worker_error).once
      # no notify email sent when dead letter message is found
      # expect(Mail::TestMailer.deliveries.length).to eq(0)
    end
  end

  context 'When no dead letter message if found' do
    it 'Sends ok message to developers' do
      issue_logger = spy('issue_logger')
      ArchivalStorageIngest.configure do |config|
        config.queuer = queuer
        config.issue_logger = issue_logger
      end
      dead_letter_monitor = DeadLetterMonitor.new(dead_letter_queues: [dead_letter_queue_name[1]])

      # Mail.defaults do
      #   delivery_method :test
      # end
      # Mail::TestMailer.deliveries.clear

      dead_letter_monitor.check_dead_letter_queues
      expect(issue_logger).to have_received(:notify_worker_error).exactly(0).times
      # notify email sent when no dead letter message is found
      # expect(Mail::TestMailer.deliveries.length).to eq(2)
    end
  end
end
