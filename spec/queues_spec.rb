# frozen_string_literal: true

require 'rspec'
require 'spec_helper'

RSpec.describe 'Queues' do
  context 'when checking valid queue names' do
    it 'succeeds on valid name' do
      valid_queue = Queues.resolve_queue_name(queue: Queues::QUEUE_PERIODIC_FIXITY,
                                              stage: ArchivalStorageIngest::STAGE_PROD)
      got = Queues.valid_queue_name?(valid_queue)
      expect(got).to be_truthy
    end

    it 'fails on invalid name' do
      got = Queues.valid_queue_name?('BOGUS_QUEUE_NAME')
      expect(got).to be_falsey

      got = Queues.valid_queue_name?('BADPREFIX_prod_ingest')
      expect(got).to be_falsey

      got = Queues.valid_queue_name?('cular_BADSTAGE_ingest')
      expect(got).to be_falsey

      got = Queues.valid_queue_name?('cular_prod_BADQUEUENAME')
      expect(got).to be_falsey
    end
  end
end
