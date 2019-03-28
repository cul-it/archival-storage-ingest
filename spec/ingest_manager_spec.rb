# frozen_string_literal: true

# rubocop:disable BlockLength

require 'spec_helper'
require 'rspec/mocks'
require 'archival_storage_ingest'
require 'mail'

RSpec.describe 'IngestManager' do
  before(:each) do
    @logger = spy('logger')
    @queuer = spy('queuer')
    @msg_q = spy('message q')
    @wip_q = spy('wip q')
    @dest1_q = spy('dest1 q')
    @dest2_q = spy('dest2 q')
    @worker = spy('worker')
    @issue_tracker_helper = spy('issue_tracker_helper')
    allow(@issue_tracker_helper).to receive(:notify_worker_started).and_return nil
    allow(@issue_tracker_helper).to receive(:notify_worker_completed).and_return nil
    allow(@issue_tracker_helper).to receive(:notify_worker_skipped).and_return nil
    allow(@issue_tracker_helper).to receive(:notify_worker_error).and_return nil

    ArchivalStorageIngest.configure do |config|
      config.logger = @logger
      config.queuer = @queuer
      config.msg_q = @msg_q
      config.wip_q = @wip_q
      config.dest_qs = [@dest1_q, @dest2_q]
      config.worker = @worker
      config.wip_removal_wait_time = 0
      config.issue_tracker_helper = @issue_tracker_helper
    end

    allow(@wip_q).to receive(:retrieve_message).and_return nil

    @manager = ArchivalStorageIngest::IngestManager.new
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
          ingest_id: 'test_id',
          depositor: 'TestDepositor',
          collection: 'TestCollection'
        )
      end

      before(:each) do
        # message = { id: 5, type: 'test' }
        allow(@msg_q).to receive(:retrieve_message).and_return message
      end

      it 'will pass message to worker' do
        @manager.do_work

        expect(@worker).to have_received(:work).with(message)
      end

      context 'Successful processing' do
        before(:each) do
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

          expect(@issue_tracker_helper).to have_received(:notify_worker_started).once
          expect(@issue_tracker_helper).to have_received(:notify_worker_completed).once
        end
      end

      context 'Processing error' do
        before(:each) do
          allow(@worker).to receive(:work).and_raise IngestException, 'This is the error'
        end

        it 'will log fatal exception' do
          expect { @manager.do_work }.to raise_error(SystemExit)

          exception = nil
          expect(@logger).to have_received(:fatal) { |ex| exception = ex }
          expect(exception).to be_an_instance_of(IngestException)
          expect(exception.message).to be('This is the error')
        end

        it 'will not pass message on to next queue' do
          expect { @manager.do_work }.to raise_error(SystemExit)

          expect(@dest1_q).to_not have_received(:send_message)
        end

        it 'will send notification to ticket handler' do
          expect { @manager.do_work }.to raise_error(SystemExit)

          expect(@issue_tracker_helper).to have_received(:notify_worker_started).once
          expect(@issue_tracker_helper).to have_received(:notify_worker_error).once
        end
      end

      context 'Processing skipped' do
        before(:each) do
          allow(@worker).to receive(:work).and_return false
        end

        it 'will not pass message on to the next queue' do
          @manager.do_work

          expect(@logger).to have_received(:info).with('Skipped test_id')
        end

        it 'will send notification to ticket handler' do
          @manager.do_work

          expect(@issue_tracker_helper).to have_received(:notify_worker_started).once
          expect(@issue_tracker_helper).to have_received(:notify_worker_skipped).once
        end
      end
    end
  end
end
# rubocop:enable BlockLength
