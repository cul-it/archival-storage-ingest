# frozen_string_literal: true

require 'spec_helper'
require 'rspec/mocks'

RSpec.describe 'IngestManager' do # rubocop:disable BlockLength
  before(:each) do
    @logger = spy('logger')
    @queuer = spy('queuer')
    @msg_q = spy('message q')
    @wip_q = spy('wip q')
    @dest1_q = spy('dest1 q')
    @dest2_q = spy('dest2 q')
    @worker = spy('worker')

    ArchivalStorageIngest.configure do |config|
      config.logger = @logger
      config.queuer = @queuer
      config.msg_q = @msg_q
      config.wip_q = @wip_q
      config.dest_qs = [@dest1_q, @dest2_q]
      config.worker = @worker
    end

    allow(@wip_q).to receive(:retrieve_message).and_return nil

    @manager = ArchivalStorageIngest::IngestManager.new
  end

  context 'when doing work' do # rubocop:disable BlockLength
    it 'will poll message queue' do
      @manager.do_work

      expect(@msg_q).to have_received(:retrieve_message).once
    end

    it 'will do nothing if no message in queue' do
      allow(@msg_q).to receive(:retrieve_message).and_return nil

      @manager.do_work

      expect(@worker).to have_received(:work).exactly(0).times

    end

    it 'will pass message to worker' do
      message = {id: 5, type: 'test'}
      allow(@msg_q).to receive(:retrieve_message).and_return message

      @manager.do_work

      expect(@worker).to have_received(:work).with(message)

    end

    it 'will pass message on to next queue' do
      message = {id: 5, type: 'test'}
      allow(@msg_q).to receive(:retrieve_message).and_return message

      @manager.do_work

      expect(@dest1_q).to have_received(:send_message).with(message)
    end
    it 'will pass message on to two next queues' do
      message = {id: 5, type: 'test'}
      allow(@msg_q).to receive(:retrieve_message).and_return message

      @manager.do_work

      expect(@dest1_q).to have_received(:send_message).with(message)
      expect(@dest2_q).to have_received(:send_message).with(message)
    end

    it 'will fail to validate Travis working' do
      expect(true).to be_falsey
    end
  end
end
