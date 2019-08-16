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

  let(:queuer) { spy('queuer') }
  let(:dir) { File.join(File.dirname(__FILE__), %w[resources manifests]) }
  let(:file) { File.join(File.dirname(__FILE__), 'resources', 'transfer_workers', 'success', 'manifest.json') }

  describe 'IngestQueuer' do # rubocop:disable BlockLength
    context 'when queuing message' do
      it 'should send message to ingest queue' do
        allow(queuer).to receive(:put_message)
          .with(Queues::QUEUE_INGEST, anything).and_return(1) # doesn't matter what we return as we don't use it
        input_checker = ArchivalStorageIngest::InputChecker.new
        input_checker.ingest_manifest = Manifests.read_manifest(filename: file)
        ArchivalStorageIngest.configure do |config|
          config.queuer = queuer
          config.message_queue_name = Queues::QUEUE_INGEST
        end
        ingest_queuer = ArchivalStorageIngest::IngestQueuer.new
        allow(ingest_queuer).to receive(:confirm_ingest) { true }
        allow(ingest_queuer).to receive(:check_input)
          .with(anything) { input_checker }
        ingest_queuer.queue_ingest('ingest_id' => 'test_id',
                                   'dest_path' => dir,
                                   'ingest_manifest' => file)
        expect(queuer).to have_received(:put_message).exactly(1).times
      end
    end

    context 'when not supplying required fields' do
      it 'should return errors' do
        input_checker = ArchivalStorageIngest::InputChecker.new
        empty_dest_path = input_checker.config_ok?('ingest_id' => 'test_id',
                                                   'ingest_manifest' => 'bogus_path')
        expect(empty_dest_path).to eq(false)
        expect(input_checker.errors.size).to eq(2)

        input_checker = ArchivalStorageIngest::InputChecker.new
        invalid_dest_path = input_checker.config_ok?('ingest_id' => 'test_id',
                                                     'dest_path' => 'bogus_path',
                                                     'ingest_manifest' => 'bogus_path')
        expect(invalid_dest_path).to eq(false)
        expect(input_checker.errors.size).to eq(2)

        input_checker = ArchivalStorageIngest::InputChecker.new
        valid_output = input_checker.config_ok?('ingest_id' => 'test_id',
                                                'dest_path' => dir,
                                                'ingest_manifest' => file)
        puts input_checker.errors
        expect(valid_output).to eq(true)
        expect(input_checker.errors.size).to eq(0)
      end
    end

    context 'when invalid ingest manifest path is given' do
      it 'should return errors' do
        input_checker = ArchivalStorageIngest::InputChecker.new
        bogus_im_path_output = input_checker.check_input('ingest_id' => 'test_id',
                                                         'dest_path' => dir,
                                                         'ingest_manifest' => 'bogus_path')
        expect(bogus_im_path_output).to eq(false)
        expect(input_checker.errors.size).to eq(1)

        # Both of these errors are invalid source_path errors.
        # I don't know how to efficiently test the success case as the test ingest manifest FILE
        # must have valid source_path attributes, unlike the transfer worker tests.
        input_checker = ArchivalStorageIngest::InputChecker.new
        valid_output = input_checker.check_input('ingest_id' => 'test_id',
                                                 'dest_path' => dir,
                                                 'ingest_manifest' => file)
        expect(valid_output).to eq(false)
        expect(input_checker.errors.size).to eq(2)
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
          .with(Queues::QUEUE_INGEST_FIXITY_S3_IN_PROGRESS).and_return(message_response)
        allow(queuer).to receive(:delete_message)
          .with(anything, Queues::QUEUE_INGEST_FIXITY_S3_IN_PROGRESS).and_return(1)
        allow(queuer).to receive(:put_message)
          .with(Queues::QUEUE_INGEST_FIXITY_S3, anything).and_return(1)
        message_mover.move_message(source: Queues::QUEUE_INGEST_FIXITY_S3_IN_PROGRESS,
                                   target: Queues::QUEUE_INGEST_FIXITY_S3)
        expect(queuer).to have_received(:retrieve_single_message).exactly(1).times
        expect(queuer).to have_received(:delete_message).exactly(1).times
        expect(queuer).to have_received(:put_message).exactly(1).times
      end
    end
  end
end
