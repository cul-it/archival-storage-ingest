# frozen_string_literal: true

require 'spec_helper'
require 'rspec/mocks'

RSpec.describe 'IngestManager' do # rubocop:disable BlockLength
  before(:each) do
    ArchivalStorageIngest.configure do |config|
      config.logger = spy('logger')
      config.queuer = spy('queuer')
      config.message_queue_name = 'incoming'
      config.dest_queue_names = %w[next1 next2]
    end

    @manager = ArchivalStorageIngest::IngestManager.new
  end

  it 'will start up' do
    expect(@manager.state).to eq('uninitialized')

    @manager.initialize_server

    expect(@manager.state).to eq('started')
  end

  context 'when doing work' do # rubocop:disable BlockLength
    it 'will poll message queue' do
      msgq = instance_double('Queuer::SQSQueue')
      expect(msgq).to receive(:retrieve_message).once
      worker = double('worker')

      @manager.do_work(msg_q: msgq, worker: worker, dest_qs: [])
    end

    it 'will do nothing if no message in queue' do
      msgq = instance_double('queuer::SQSQueue')
      worker = double('worker')
      expect(msgq).to receive(:retrieve_message).and_return nil

      @manager.do_work(msg_q: msgq, worker: worker, dest_qs: [])
    end

    it 'will pass message to worker' do
      message = {id: 5, type: 'test'}
      msgq = instance_double('Queuer::SQSQueue',
                             retrieve_message: message)
      expect(msgq).to receive(:retrieve_message).and_return message
      worker = double('worker')
      expect(worker).to receive(:work).with(message)

      @manager.do_work(msg_q: msgq, worker: worker, dest_qs: [])
    end

    it 'will pass message on to next queue' do
      message = {id: 5, type: 'test'}
      msgq = instance_double('Queuer::SQSQueue',
                             retrieve_message: message)
      expect(msgq).to receive(:retrieve_message).and_return message
      worker = double('worker')
      expect(worker).to receive(:work).with(message)

      destq = instance_double('Queuer::SQSQueue')
      expect(destq).to receive(:send_message).with(message)

      @manager.do_work(msg_q: msgq, worker: worker, dest_qs: [destq])
    end
    it 'will pass message on to two next queues' do
      message = {id: 5, type: 'test'}
      msgq = instance_double('Queuer::SQSQueue',
                             retrieve_message: message)
      expect(msgq).to receive(:retrieve_message).and_return message
      worker = double('worker')
      expect(worker).to receive(:work).with(message)

      destq1 = instance_double('Queuer::SQSQueue')
      expect(destq1).to receive(:send_message).with(message)
      destq2 = instance_double('Queuer::SQSQueue')
      expect(destq2).to receive(:send_message).with(message)

      @manager.do_work(msg_q: msgq, worker: worker, dest_qs: [destq1, destq2])
    end
  end
end
