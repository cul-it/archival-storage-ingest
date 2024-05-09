# frozen_string_literal: true

require 'spec_helper'
require 'rspec/mocks'
require 'pathname'
require 'archival_storage_ingest/ingest_utils/ingest_utils'
require 'archival_storage_ingest/manifests/manifests'
require 'archival_storage_ingest/workers/transfer_state_manager'
require 'archival_storage_ingest/workers/ingest_worker'

def ingest_manifest_io(manifest_path:, replace_path:)
  f_ingest_manifest = File.open(manifest_path)
  str_manifest = f_ingest_manifest.read
  f_ingest_manifest.close
  StringIO.new(str_manifest.gsub('REPLACE_ME', replace_path))
end

RSpec.describe 'IngestWorker' do
  let(:dest_path) do
    File.join(File.dirname(__FILE__), 'resources', 'fixity_workers', 'sfs', 'archival01', 'RMC', 'RMA', 'RMA0001234')
  end
  let(:job_id) { 'test_1234' }
  let(:depositor) { 'RMC/RMA' }
  let(:collection) { 'RMA0001234' }
  let(:success_dir) do
    File.join(File.dirname(__FILE__), 'resources', 'transfer_workers', 'success', 'RMC', 'RMA', collection)
  end
  let(:success_ingest_manifest) do
    File.join(File.dirname(__FILE__), 'resources', 'transfer_workers', 'success', 'manifest.json')
  end
  let(:success_msg) do
    IngestMessage::SQSMessage.new(
      job_id:,
      dest_path: dest_path.to_s,
      depositor:,
      collection:,
      ingest_manifest: success_ingest_manifest
    )
  end
  let(:expected_s3_key) { 'RMC/RMA/RMA0001234/1/resource1.txt' }
  let(:ingest_manifest_s3_key) { ".manifest/#{job_id}_#{Workers::TYPE_INGEST}.json" }

  let(:platforms) do
    [
      IngestUtils::PLATFORM_S3, IngestUtils::PLATFORM_S3_WEST,
      IngestUtils::PLATFORM_SFS, IngestUtils::PLATFORM_WASABI
    ]
  end

  let(:transfer_state_manager) do
    TransferStateManager::TestTransferStateManager.new
  end

  before do
    @s3_bucket = spy('s3_bucket')
    @s3_manager = spy('s3_manager')
    @application_logger = spy('application_logger')
    @ingest_worker = IngestWorker.new(
      @application_logger, transfer_state_manager, platforms, @s3_manager
    )

    allow(@s3_manager).to receive(:upload_file)
      .with("#{ingest_manifest_s3_key}", anything).and_return(true)
    allow(@s3_manager).to receive(:upload_string)
      .with(any_args)
      .and_raise(IngestException, 'upload_string must not be called in this test!')
    allow(@s3_manager).to receive(:manifest_key)
      .with(job_id, Workers::TYPE_INGEST) { ingest_manifest_s3_key }
  end

  context 'when initiating work' do
    it 'Uploads ingest manifest and updates transfer state' do
      ingest_manifest = ingest_manifest_io(manifest_path: success_ingest_manifest, replace_path: success_dir)
      allow(@s3_manager).to receive(:retrieve_file)
        .with(ingest_manifest_s3_key) { ingest_manifest }

      expect(@ingest_worker.work(success_msg)).to be(true)
      expect(@s3_manager).to have_received(:upload_file).exactly(1).times

      platforms.each do |platform|
        next if platform == IngestUtils::PLATFORM_SFS

        got = transfer_state_manager.get_transfer_state(job_id: success_msg.job_id, platform:)
        expect(got).to eq(IngestUtils::TRANSFER_STATE_IN_PROGRESS)
      end
      expect(transfer_state_manager.get_transfer_state(job_id: success_msg.job_id, platform: IngestUtils::PLATFORM_SFS)).to be(nil)
      expect(transfer_state_manager.transfer_complete?(job_id: success_msg.job_id)).to be(false)
    end
  end
end
