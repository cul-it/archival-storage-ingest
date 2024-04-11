# frozen_string_literal: true

require 'spec_helper'
require 'rspec/mocks'
require 'pathname'
require 'archival_storage_ingest/manifests/manifests'
require 'archival_storage_ingest/workers/transfer_state_manager'
require 'archival_storage_ingest/workers/transfer_worker'

RSpec.shared_context 'transfer_worker_shared_examples' do
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

  let(:fail_dir) do
    File.join(File.dirname(__FILE__), 'resources', 'transfer_workers', 'fail', 'RMC', 'RMA', collection)
  end
  let(:fail_ingest_manifest) do
    File.join(File.dirname(__FILE__), 'resources', 'transfer_workers', 'fail', 'manifest.json')
  end

  let(:symlink_dir) do
    File.join(File.dirname(__FILE__), 'resources', 'transfer_workers', 'symlink', 'RMC', 'RMA', collection)
  end
  let(:symlink_ingest_manifest) do
    File.join(File.dirname(__FILE__), 'resources', 'transfer_workers', 'symlink', 'manifest.json')
  end

  let(:transfer_staet_manager) do
    TransferStateManager::TestTransferStateManager.new
  end
end

def ingest_manifest_io(manifest_path:, replace_path:)
  f_ingest_manifest = File.open(manifest_path)
  str_manifest = f_ingest_manifest.read
  f_ingest_manifest.close
  StringIO.new(str_manifest.gsub('REPLACE_ME', replace_path))
end

RSpec.describe 'S3TransferWorker' do
  before do
    @s3_bucket = spy('s3_bucket')
    @s3_manager = spy('s3_manager')
    @application_logger = spy('application_logger')
    @s3_worker = TransferWorker::S3Transferer.new(@application_logger, transfer_staet_manager, @s3_manager)

    allow(@s3_manager).to receive(:upload_file)
      .with("#{depositor}/#{collection}/1/resource1.txt", anything).and_return(true)
    allow(@s3_manager).to receive(:upload_file)
      .with("#{depositor}/#{collection}/2/resource2.txt", anything).and_return(true)
    allow(@s3_manager).to receive(:upload_file)
      .with("#{depositor}/#{collection}/3/resource3.txt", anything)
      .and_raise(IngestException, 'Test error message')
    allow(@s3_manager).to receive(:upload_file)
      .with("#{depositor}/#{collection}/4/resource4.txt", anything).and_return(true)
    allow(@s3_manager).to receive(:upload_string)
      .with(any_args)
      .and_raise(IngestException, 'upload_string must not be called in this test!')
    allow(@s3_manager).to receive(:manifest_key)
      .with(job_id, Workers::TYPE_INGEST) { ingest_manifest_s3_key }
  end

  include_examples 'transfer_worker_shared_examples'

  context 'when generating target' do
    it 'returns relative portion of file path as the key' do
      file = Manifests::FileEntry.new(
        file: {
          filepath: '1/resource1.txt',
          sha1: 'ef72cf86c1599c80612317fdd2f50f4863c3efb0',
          size: 10
        }
      )
      expect(@s3_worker.target(msg: success_msg, file:)).to eq(expected_s3_key)
    end
  end

  context 'when processing file' do
    it 'uploads file' do
      path = File.join(File.dirname(__FILE__),
                       'resources', 'transfer_workers', 'success', depositor, collection, '1', 'resource1.txt')
      @s3_worker.process_file(source: path, target: expected_s3_key)
      expect(@s3_manager).to have_received(:upload_file).once
    end
  end

  context 'when doing successful work' do
    it 'uploads files' do
      ingest_manifest = ingest_manifest_io(manifest_path: success_ingest_manifest, replace_path: success_dir)
      allow(@s3_manager).to receive(:retrieve_file)
        .with(ingest_manifest_s3_key) { ingest_manifest }

      expect(@s3_worker.work(success_msg)).to be(true)
      expect(@s3_manager).to have_received(:upload_file).exactly(2).times
    end
  end

  context 'when doing failing work' do
    it 'raises error' do
      fail_msg = IngestMessage::SQSMessage.new(
        job_id:,
        dest_path: dest_path.to_s,
        depositor:,
        collection:,
        ingest_manifest: fail_ingest_manifest
      )

      ingest_manifest = ingest_manifest_io(manifest_path: fail_ingest_manifest, replace_path: fail_dir)
      allow(@s3_manager).to receive(:retrieve_file)
        .with(ingest_manifest_s3_key) { ingest_manifest }

      expect do
        @s3_worker.work(fail_msg)
      end.to raise_error(IngestException, 'Test error message')

      # Dir.glob returns listing in an arbitrary order.
      # I don't want it to sort just for this test.
      # expect(@s3_manager).to have_received(:upload_file).once
    end
  end

  context 'when working on directory containing symlinked directory' do
    it 'follows symlinks correctly' do
      ingest_manifest = ingest_manifest_io(manifest_path: symlink_ingest_manifest, replace_path: symlink_dir)
      allow(@s3_manager).to receive(:retrieve_file)
        .with(ingest_manifest_s3_key) { ingest_manifest }

      symlink_msg = IngestMessage::SQSMessage.new(
        job_id: 'test_1234',
        depositor:,
        collection:,
        ingest_manifest: symlink_ingest_manifest
      )
      expect(@s3_worker.work(symlink_msg)).to be(true)

      expect(@s3_manager).to have_received(:upload_file).exactly(3).times
    end
  end
end

RSpec.describe 'SFSTransferWorker' do
  before do
    @s3_bucket = spy('s3_bucket')
    @s3_manager = spy('s3_manager')
    @application_logger = spy('application_logger')
    @sfs_worker = TransferWorker::SFSTransferer.new(@application_logger, transfer_staet_manager, @s3_manager)

    allow(@s3_manager).to receive(:upload_file)
      .with(any_args)
      .and_raise(IngestException, 'upload_string file not be called in this test!')
    allow(@s3_manager).to receive(:upload_string)
      .with(any_args)
      .and_raise(IngestException, 'upload_string must not be called in this test!')
    allow(@s3_manager).to receive(:manifest_key)
      .with(job_id, Workers::TYPE_INGEST) { ingest_manifest_s3_key }

    allow(FileUtils).to receive(:mkdir_p).with("#{dest_path}/1").and_return(nil)
    allow(FileUtils).to receive(:mkdir_p).with("#{dest_path}/2").and_return(nil)
    allow(FileUtils).to receive(:mkdir_p).with("#{dest_path}/4").and_return(nil)
    allow(FileUtils).to receive(:copy)
      .with("#{symlink_dir}/1/resource1.txt", "#{dest_path}/1/resource1.txt").and_return(nil)
    allow(FileUtils).to receive(:copy)
      .with("#{symlink_dir}/2/resource2.txt", "#{dest_path}/2/resource2.txt").and_return(nil)
    allow(FileUtils).to receive(:copy)
      .with("#{symlink_dir}/4/resource4.txt", "#{dest_path}/4/resource4.txt").and_return(nil)
  end

  include_examples 'transfer_worker_shared_examples'

  context 'when generating source' do
    it 'constructs correct source path' do
      ingest_manifest = ingest_manifest_io(manifest_path: symlink_ingest_manifest, replace_path: symlink_dir)
      allow(@s3_manager).to receive(:retrieve_file)
        .with(ingest_manifest_s3_key) { ingest_manifest }
      im = @sfs_worker.fetch_ingest_manifest(success_msg)
      package = im.packages[0]
      source_path = package.source_path
      file = package.files[0]
      source = @sfs_worker.source(source_path:, file:)
      expect(source).to eq("#{symlink_dir}/1/resource1.txt")
    end
  end

  context 'when working on directory containing symlinked directory' do
    it 'follows symlinks correctly' do
      ingest_manifest = ingest_manifest_io(manifest_path: symlink_ingest_manifest, replace_path: symlink_dir)
      allow(@s3_manager).to receive(:retrieve_file)
        .with(ingest_manifest_s3_key) { ingest_manifest }

      symlink_msg = IngestMessage::SQSMessage.new(
        job_id: 'test_1234',
        dest_path: dest_path.to_s,
        depositor:,
        collection:,
        ingest_manifest: symlink_ingest_manifest
      )
      expect(@sfs_worker.work(symlink_msg)).to be(true)
      expect(FileUtils).to have_received(:mkdir_p).exactly(3).times
      expect(FileUtils).to have_received(:copy).exactly(3).times
    end
  end
end
