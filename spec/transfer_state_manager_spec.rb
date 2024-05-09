# frozen_string_literal: true

require 'archival_storage_ingest/ingest_utils/ingest_utils'
require 'archival_storage_ingest/workers/parameter_store'
require 'archival_storage_ingest/workers/transfer_state_manager'

RSpec.describe TransferStateManager do
  let(:transfer_state_manager) do
    TransferStateManager::TestTransferStateManager.new
  end
  let(:job_id) { 'a2310656-4313-4fcd-91ce-40377553f4ae' }
  let(:platform) { IngestUtils::PLATFORM_S3 }

  describe '#add_transfer_state' do
    it 'adds the correct state' do
      transfer_state_manager.add_transfer_state(job_id:, platform:, state: IngestUtils::TRANSFER_STATE_IN_PROGRESS)
      expect(transfer_state_manager.transfer_complete?(job_id:)).to be_falsey
    end
  end

  describe '#set_transfer_state' do
    it 'executes the query with the correct parameters' do
      transfer_state_manager.add_transfer_state(job_id:, platform:, state: IngestUtils::TRANSFER_STATE_IN_PROGRESS)
      transfer_state_manager.set_transfer_state(job_id:, platform:, state: IngestUtils::TRANSFER_STATE_COMPLETE)
      expect(transfer_state_manager.transfer_complete?(job_id:)).to be_truthy
    end
  end
end
