# frozen_string_literal: true

require 'rspec'
require 'spec_helper'

RSpec.describe 'Queues' do
  context 'when checking valid queue names' do
    it 'succeeds on valid name' do
      got = Queues.valid_queue_name?(Queues::QUEUE_PERIODIC_FIXITY)
      expect(got).to be_truthy
    end

    it 'fails on invalid name' do
      got = Queues.valid_queue_name?('BOGUS_QUEUE_NAME')
      expect(got).to be_falsey
    end
  end
end
