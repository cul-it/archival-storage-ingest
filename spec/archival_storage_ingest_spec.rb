# frozen_string_literal: true

require 'rspec'
require 'rspec/mocks'
require 'spec_helper'
require 'archival_storage_ingest'
require 'archival_storage_ingest/messages/ingest_queue'
require 'archival_storage_ingest/messages/queues'
require 'archival_storage_ingest/work_queuer/input_checker'
require 'archival_storage_ingest/work_queuer/work_queuer'
require 'json'

RSpec.describe ArchivalStorageIngest do
  let(:queue_ingest) do
    Queues.resolve_queue_name(queue: Queues::QUEUE_INGEST, stage: ArchivalStorageIngest::STAGE_PROD)
  end
  let(:file) { File.join(File.dirname(__FILE__), 'resources', 'transfer_workers', 'success', 'manifest.json') }
  let(:dir) { File.join(File.dirname(__FILE__), %w[resources manifests]) }
  let(:queuer) { spy('queuer') }

  it 'has a version number' do
    expect(ArchivalStorageIngest::VERSION).not_to be_nil
  end

  describe 'IngestQueuer' do
    context 'when queuing message' do
      it 'sends message to ingest queue' do
        allow(queuer).to receive(:put_message)
          .with(queue_ingest, anything).and_return(1) # doesn't matter what we return as we don't use it
        input_checker = WorkQueuer::IngestInputChecker.new
        input_checker.ingest_manifest = Manifests.read_manifest(filename: file)
        issue_logger = spy('issue_logger')
        described_class.configure do |config|
          config.queuer = queuer
          config.message_queue_name = queue_ingest
          config.issue_logger = issue_logger
        end
        ingest_queuer = WorkQueuer::IngestQueuer.new
        allow(ingest_queuer).to receive(:confirm_work).and_return(true)
        allow(ingest_queuer).to receive(:input_checker_impl) { WorkQueuer::YesManInputChecker.new }
        ingest_queuer.queue_work(type: IngestMessage::TYPE_INGEST, job_id: 'test_id',
                                 dest_path: dir, ingest_manifest: file)
        expect(queuer).to have_received(:put_message).exactly(1).times
        expect(issue_logger).to have_received(:notify_status).exactly(1).times
      end
    end

    context 'when not supplying required fields' do
      it 'returns errors' do
        input_checker = WorkQueuer::IngestInputChecker.new
        empty_dest_path = input_checker.check_input(job_id: 'test_id',
                                                    ingest_manifest: 'bogus_path')
        expect(empty_dest_path).to be(false)
        expect(input_checker.errors.size).to eq(2)

        input_checker = WorkQueuer::IngestInputChecker.new
        invalid_dest_path = input_checker.check_input(job_id: 'test_id',
                                                      dest_path: 'bogus_path',
                                                      ingest_manifest: 'bogus_path')
        expect(invalid_dest_path).to be(false)
        expect(input_checker.errors.size).to eq(2)

        # Both of these errors are invalid source_path errors.
        # I don't know how to efficiently test the success case as the test ingest manifest FILE
        # must have valid source_path attributes, unlike the transfer worker tests.
        input_checker = WorkQueuer::IngestInputChecker.new
        valid_output = input_checker.check_input(job_id: 'test_id',
                                                 dest_path: dir,
                                                 ingest_manifest: file)
        expect(valid_output).to be(false)
        expect(input_checker.errors.size).to eq(2)
      end
    end

    context 'when invalid ingest manifest path is given' do
      it 'returns errors' do
        input_checker = WorkQueuer::IngestInputChecker.new
        bogus_im_path_output = input_checker.check_input(job_id: 'test_id',
                                                         dest_path: dir,
                                                         ingest_manifest: 'bogus_path')
        expect(bogus_im_path_output).to be(false)
        expect(input_checker.errors.size).to eq(1)

        # Both of these errors are invalid source_path errors.
        # I don't know how to efficiently test the success case as the test ingest manifest FILE
        # must have valid source_path attributes, unlike the transfer worker tests.
        input_checker = WorkQueuer::IngestInputChecker.new
        valid_output = input_checker.check_input(job_id: 'test_id',
                                                 dest_path: dir,
                                                 ingest_manifest: file)
        expect(valid_output).to be(false)
        expect(input_checker.errors.size).to eq(2)
      end
    end
  end

  describe 'MessageMover' do
    let(:message_mover) do
      described_class.configure do |config|
        config.queuer = queuer
      end
      ArchivalStorageIngest::MessageMover.new
    end

    let(:message_response) do
      resp = spy('body')
      allow(resp).to receive(:body) { { job_id: 'test' }.to_json }
      resp
    end

    let(:queue_ingest_fixity_s3) do
      Queues.resolve_queue_name(queue: Queues::QUEUE_INGEST_FIXITY_S3, stage: ArchivalStorageIngest::STAGE_PROD)
    end
    let(:queue_ingest_fixity_s3_in_progress) do
      Queues.resolve_in_progress_queue_name(queue: Queues::QUEUE_INGEST_FIXITY_S3,
                                            stage: ArchivalStorageIngest::STAGE_PROD)
    end

    context 'when moving message' do
      it 'removes from source queue and add to target queue' do
        allow(queuer).to receive(:retrieve_single_message)
          .with(queue_ingest_fixity_s3_in_progress).and_return(message_response)
        allow(queuer).to receive(:delete_message)
          .with(anything, queue_ingest_fixity_s3_in_progress).and_return(1)
        allow(queuer).to receive(:put_message)
          .with(queue_ingest_fixity_s3, anything).and_return(1)
        message_mover.move_message(source: queue_ingest_fixity_s3_in_progress,
                                   target: queue_ingest_fixity_s3)
        expect(queuer).to have_received(:retrieve_single_message).exactly(1).times
        expect(queuer).to have_received(:delete_message).exactly(1).times
        expect(queuer).to have_received(:put_message).exactly(1).times
      end
    end
  end
end
