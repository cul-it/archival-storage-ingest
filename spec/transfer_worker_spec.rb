# frozen_string_literal: true

require 'spec_helper'
require 'rspec/mocks'
require 'pathname'

RSpec.describe 'S3TransferWorker' do # rubocop:disable BlockLength
  before(:each) do
    @s3_bucket = spy('s3_bucket')
    @s3_manager = spy('s3_manager')
    @worker = TransferWorker::S3Transferer.new(@s3_manager)

    allow(@s3_manager).to receive(:upload_file)
      .with('RMC/RMA/RMA0001234/1/resource1.txt', anything) { true }
    allow(@s3_manager).to receive(:upload_file)
      .with('RMC/RMA/RMA0001234/2/resource2.txt', anything) { true }
    allow(@s3_manager).to receive(:upload_file)
      .with('RMC/RMA/RMA0001234/3/resource3.txt', anything)
      .and_raise(IngestException, 'Test error message')
    allow(@s3_manager).to receive(:upload_file)
      .with('RMC/RMA/RMA0001234/4/resource4.txt', anything) { true }
  end

  context 'when doing successful work' do
    it 'uploads files' do
      success_data_path = File.join(File.dirname(__FILE__), 'resources', 'transfer_workers', 'success', 'RMC')
      msg = IngestMessage::SQSMessage.new(
        ingest_id: 'test_1234',
        data_path: success_data_path.to_s
      )
      expect(@worker.work(msg)).to eq(true)

      expect(@s3_manager).to have_received(:upload_file).exactly(2).times
    end
  end

  context 'when doing failing work' do
    it 'raises error' do
      fail_data_path = File.join(File.dirname(__FILE__), 'resources', 'transfer_workers', 'fail', 'RMC')
      msg = IngestMessage::SQSMessage.new(
        ingest_id: 'test_5678',
        data_path: fail_data_path.to_s
      )
      expect do
        @worker.work(msg)
      end.to raise_error(IngestException, 'Test error message')

      expect(@s3_manager).to have_received(:upload_file).once
    end
  end

  context 'when working on directory containing symlinked directory' do
    it 'follows symlinks correctly' do
      symlinked_data_path = File.join(File.dirname(__FILE__), 'resources', 'transfer_workers', 'symlink', 'RMC')
      msg = IngestMessage::SQSMessage.new(
        ingest_id: 'test_1234',
        data_path: symlinked_data_path.to_s
      )
      expect(@worker.work(msg)).to eq(true)

      expect(@s3_manager).to have_received(:upload_file).exactly(3).times
    end
  end

  context 'when traversing directory containing symlink' do
    it 'returns list of symlinked directory' do
      symlinked_data_path = File.join(File.dirname(__FILE__), 'resources', 'transfer_workers', 'symlink', 'RMC')
      expected_symlink = File.join(symlinked_data_path, 'RMA', 'RMA0001234', '2')
      path_to_trim = Pathname.new(symlinked_data_path).parent
      expect(@worker.traverse(symlinked_data_path.to_s, path_to_trim)).to eq([expected_symlink])
    end
  end
end

RSpec.describe 'SFSTransferWorker' do # rubocop:disable BlockLength
  before(:each) do
    @worker = TransferWorker::SFSTransferer.new
    @symlinked_data_path = File.join(File.dirname(__FILE__), 'resources', 'transfer_workers', 'symlink', 'RMC')
    @symlink_real_path = File.join(File.dirname(__FILE__), 'resources', 'transfer_workers', 'symlink', '2')
    @test_dest_root = File.join(File.dirname(__FILE__), 'resources', 'transfer_workers')

    allow(FileUtils).to receive(:mkdir).with("#{@test_dest_root}/RMC") { nil }
    allow(FileUtils).to receive(:mkdir).with("#{@test_dest_root}/RMC/RMA") { nil }
    allow(FileUtils).to receive(:mkdir).with("#{@test_dest_root}/RMC/RMA/RMA0001234") { nil }
    allow(FileUtils).to receive(:mkdir).with("#{@test_dest_root}/RMC/RMA/RMA0001234/1") { nil }
    allow(FileUtils).to receive(:mkdir).with("#{@test_dest_root}/RMC/RMA/RMA0001234/2") { nil }
    allow(FileUtils).to receive(:mkdir).with("#{@test_dest_root}/RMC/RMA/RMA0001234/4") { nil }
    allow(FileUtils).to receive(:copy)
      .with("#{@symlinked_data_path}/RMA/RMA0001234/1/resource1.txt",
            "#{@test_dest_root}/RMC/RMA/RMA0001234/1/resource1.txt") { nil }
    allow(FileUtils).to receive(:copy)
      .with("#{@symlink_real_path}/resource2.txt",
            "#{@test_dest_root}/RMC/RMA/RMA0001234/2/resource2.txt") { nil }
    allow(FileUtils).to receive(:copy)
      .with("#{@symlinked_data_path}/RMA/RMA0001234/4/resource4.txt",
            "#{@test_dest_root}/RMC/RMA/RMA0001234/4/resource4.txt") { nil }
  end

  context 'when generating destination path' do
    it 'combines relative path portion of the file to destination root directory' do
      worker = TransferWorker::SFSTransferer.new
      dest_root_dir = '/dest'
      file_path = '/a/data/abc/resource.txt'
      path_to_trim = Pathname.new('/a/data')
      expected = '/dest/abc/resource.txt'
      expect(worker.get_dest_path(dest_root_dir, file_path, path_to_trim)).to eq(expected)
    end
  end

  context 'when working on directory containing symlinked directory' do
    it 'follows symlinks correctly' do
      msg = IngestMessage::SQSMessage.new(
        ingest_id: 'test_1234',
        data_path: @symlinked_data_path.to_s,
        dest_path: @test_dest_root
      )
      expect(@worker.work(msg)).to eq(true)

      expect(FileUtils).to have_received(:copy).exactly(3).times
    end
  end

  context 'when traversing directory containing symlink' do
    it 'returns list of symlinked directory' do
      expected_symlink = File.join(@symlinked_data_path, 'RMA', 'RMA0001234', '2')
      path_to_trim = Pathname.new(@symlinked_data_path).parent
      expect(@worker.traverse(@symlinked_data_path.to_s, @test_dest_root.to_s, path_to_trim)).to eq([expected_symlink])
    end
  end
end
