# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength

require 'spec_helper'
require 'rspec/mocks'
require 'archival_storage_ingest'
require 'archival_storage_ingest/messages/ingest_message'
require 'mail'

RSpec.describe 'IngestManager' do
  before do
    @logger = spy('logger')
    @queuer = spy('queuer')
    @msg_q = spy('message q')
    @wip_q = spy('wip q')
    @dest1_q = spy('dest1 q')
    @dest2_q = spy('dest2 q')
    @worker = spy('worker')
    @issue_logger = spy('issue_logger')
    allow(@issue_logger).to receive(:notify_worker_started).and_return nil
    allow(@issue_logger).to receive(:notify_worker_completed).and_return nil
    allow(@issue_logger).to receive(:notify_worker_skipped).and_return nil
    allow(@issue_logger).to receive(:notify_worker_error).and_return nil
    allow(@issue_logger).to receive(:notify_error).and_return nil

    ArchivalStorageIngest.configure do |config|
      config.logger = @logger
      config.queuer = @queuer
      config.msg_q = @msg_q
      config.wip_q = @wip_q
      config.dest_qs = [@dest1_q, @dest2_q]
      config.worker = @worker
      config.wip_removal_wait_time = 0
      config.issue_logger = @issue_logger
    end

    allow(@wip_q).to receive(:retrieve_message).and_return nil

    @manager = ArchivalStorageIngest::IngestManager.new
    allow(@manager).to receive(:check_wip).and_return nil
    allow(@manager).to receive(:remove_wip_msg).and_return nil
  end

  context 'when shutting down' do
    it 'will shutdown' do
      expect { @manager.shutdown }.to raise_error(SystemExit)
      expect(@logger).to have_received(:info).with('Gracefully shutting down')
    end
  end

  context 'when doing work' do
    it 'will poll message queue' do
      @manager.do_work

      expect(@msg_q).to have_received(:retrieve_message).once
    end

    it 'will do nothing if no message in queue' do
      allow(@msg_q).to receive(:retrieve_message).and_return nil

      @manager.do_work

      expect(@worker).to have_received(:work).exactly(0).times
    end

    context 'when receiving a message' do
      let(:message) do
        IngestMessage::SQSMessage.new(
          job_id: 'test_id',
          depositor: 'TestDepositor',
          collection: 'TestCollection'
        )
      end

      before do
        # message = { id: 5, type: 'test' }
        allow(@msg_q).to receive(:retrieve_message).and_return message
      end

      it 'will pass message to worker' do
        @manager.do_work

        expect(@worker).to have_received(:work).with(message)
      end

      context 'Successful processing' do
        before do
          allow(@worker).to receive(:work).and_return true
        end

        it 'will log success' do
          @manager.do_work

          expect(@logger).to have_received(:info).with('Completed test_id')
        end

        it 'will pass message on to next queue' do
          @manager.do_work

          expect(@dest1_q).to have_received(:send_message).with(message)
        end

        it 'will pass message on to two next queues' do
          @manager.do_work

          expect(@dest1_q).to have_received(:send_message).with(message)
          expect(@dest2_q).to have_received(:send_message).with(message)
        end

        it 'will log that the message was received' do
          @manager.do_work

          expect(@logger).to have_received(:info).with("Received #{message.to_json}")
        end

        it 'will send notification to ticket handler' do
          @manager.do_work

          expect(@issue_logger).to have_received(:notify_worker_started).once
          expect(@issue_logger).to have_received(:notify_worker_completed).once
        end
      end

      context 'Processing error' do
        before do
          allow(@worker).to receive(:work).and_raise IngestException, 'This is the error'
        end

        it 'will log fatal exception' do
          expect { @manager.do_work }.to raise_error(SystemExit)

          exception = nil
          expect(@logger).to have_received(:fatal) { |ex| exception = ex }
          expect(exception).to be_an_instance_of(IngestException)
          expect(exception.message).to be('This is the error')
        end

        it 'will send notification to ticket handler and will not pass message on to next queue' do
          expect { @manager.do_work }.to raise_error(SystemExit)

          expect(@issue_logger).to have_received(:notify_worker_started).once
          expect(@issue_logger).to have_received(:notify_worker_error).once
          expect(@dest1_q).not_to have_received(:send_message)
        end
      end

      context 'Processing skipped' do
        before do
          allow(@worker).to receive(:work).and_return false
        end

        it 'will not pass message on to the next queue' do
          @manager.do_work

          expect(@logger).to have_received(:info).with('Skipped test_id')
        end

        it 'will send notification to ticket handler' do
          @manager.do_work

          expect(@issue_logger).to have_received(:notify_worker_started).once
          expect(@issue_logger).to have_received(:notify_worker_skipped).once
        end
      end
    end
  end
end

RSpec.describe 'IngestManager' do
  let(:message) do
    IngestMessage::SQSMessage.new(
      job_id: 'test_id',
      depositor: 'TestDepositor',
      collection: 'TestCollection'
    )
  end

  before do
    @logger = spy('logger')
    @queuer = spy('queuer')
    @msg_q = spy('message q')
    @wip_q = spy('wip q')
    @dest1_q = spy('dest1 q')
    @dest2_q = spy('dest2 q')
    @worker = spy('worker')
    @issue_logger = spy('issue_logger')
    allow(@issue_logger).to receive(:notify_worker_started).and_return nil
    allow(@issue_logger).to receive(:notify_worker_completed).and_return nil
    allow(@issue_logger).to receive(:notify_worker_skipped).and_return nil
    allow(@issue_logger).to receive(:notify_worker_error).and_return nil
    allow(@issue_logger).to receive(:notify_error).and_return nil

    ArchivalStorageIngest.configure do |config|
      config.logger = @logger
      config.queuer = @queuer
      config.msg_q = @msg_q
      config.wip_q = @wip_q
      config.dest_qs = [@dest1_q, @dest2_q]
      config.worker = @worker
      config.wip_removal_wait_time = 0
      config.issue_logger = @issue_logger
    end

    allow(@wip_q).to receive(:retrieve_message).and_return message

    @manager = ArchivalStorageIngest::IngestManager.new
  end

  context 'when there is an existing message in WIP queue' do
    it 'will send error notification and exit' do
      allow(@wip_q).to receive(:retrieve_message).and_return message

      expect { @manager.do_work }.to raise_error(SystemExit)
      expect(@worker).not_to have_received(:work)
      expect(@issue_logger).to have_received(:notify_error).once
      expect(@issue_logger).not_to have_received(:notify_worker_started)
      expect(@dest1_q).not_to have_received(:send_message)
    end
  end
end
# rubocop:enable Metrics/BlockLength
