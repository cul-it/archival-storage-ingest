# frozen_string_literal: true

require 'spec_helper'
require 'rspec/mocks'
require 'pathname'

RSpec.describe 'S3TransferWorker' do # rubocop:disable BlockLength
  before(:each) do
    @s3_bucket = spy('s3_bucket')
    @s3_manager = spy('s3_manager')
    @worker = TransferWorker::S3Transferer.new(@s3_manager)
    @depositor = 'RMC/RMA'
    @collection = 'RMA0001234'

    allow(@s3_manager).to receive(:upload_file)
      .with("#{@depositor}/#{@collection}/1/resource1.txt", anything) { true }
    allow(@s3_manager).to receive(:upload_file)
      .with("#{@depositor}/#{@collection}/2/resource2.txt", anything) { true }
    allow(@s3_manager).to receive(:upload_file)
      .with("#{@depositor}/#{@collection}/3/resource3.txt", anything)
      .and_raise(IngestException, 'Test error message')
    allow(@s3_manager).to receive(:upload_file)
      .with("#{@depositor}/#{@collection}/4/resource4.txt", anything) { true }
    allow(@s3_manager).to receive(:upload_string)
      .with(any_args)
      .and_raise(IngestException, 'upload_string must not be called in this test!')
  end

  context 'when generating s3 key' do
    it 'returns relative portion of file path as the key' do
      file = '/a/b/c/resource.txt'
      path_to_trim = Pathname.new('/a/b')
      expected_s3_key = 'c/resource.txt'
      expect(@worker.s3_key(file, path_to_trim)).to eq(expected_s3_key)
    end
  end

  context 'when processing path' do
    it 'skips directory' do
      path = File.join(File.dirname(__FILE__),
                       'resources', 'transfer_workers', 'success', @depositor, @collection, '1')
      path_to_trim = File.join(File.dirname(__FILE__),
                               'resources', 'transfer_workers', 'success')
      path_to_trim = Pathname.new(path_to_trim)
      expect(@worker.process_path(path, path_to_trim)).to be_nil
      expect(@s3_manager).to have_received(:upload_file).exactly(0).times
    end

    it 'uploads file' do
      path = File.join(File.dirname(__FILE__),
                       'resources', 'transfer_workers', 'success', @depositor, @collection, '1', 'resource1.txt')
      path_to_trim = File.join(File.dirname(__FILE__),
                               'resources', 'transfer_workers', 'success')
      path_to_trim = Pathname.new(path_to_trim)
      @worker.process_path(path, path_to_trim)
      expect(@s3_manager).to have_received(:upload_file).once
    end
  end

  context 'when doing successful work' do
    it 'uploads files' do
      success_data_path = File.join(File.dirname(__FILE__), 'resources', 'transfer_workers', 'success')
      msg = IngestMessage::SQSMessage.new(
        ingest_id: 'test_1234',
        data_path: success_data_path.to_s,
        depositor: @depositor,
        collection: @collection
      )
      expect(@worker.work(msg)).to eq(true)

      expect(@s3_manager).to have_received(:upload_file).exactly(2).times
    end
  end

  context 'when doing failing work' do
    it 'raises error' do
      fail_data_path = File.join(File.dirname(__FILE__), 'resources', 'transfer_workers', 'fail')
      msg = IngestMessage::SQSMessage.new(
        ingest_id: 'test_5678',
        data_path: fail_data_path.to_s,
        depositor: @depositor,
        collection: @collection
      )
      expect do
        @worker.work(msg)
      end.to raise_error(IngestException, 'Test error message')

      # Dir.glob returns listing in an arbitrary order.
      # I don't want it to sort just for this test.
      # expect(@s3_manager).to have_received(:upload_file).once
    end
  end

  context 'when working on directory containing symlinked directory' do
    it 'follows symlinks correctly' do
      symlinked_data_path = File.join(File.dirname(__FILE__), 'resources', 'transfer_workers', 'symlink')
      msg = IngestMessage::SQSMessage.new(
        ingest_id: 'test_1234',
        data_path: symlinked_data_path.to_s,
        depositor: @depositor,
        collection: @collection
      )
      expect(@worker.work(msg)).to eq(true)

      expect(@s3_manager).to have_received(:upload_file).exactly(3).times
    end
  end
end

RSpec.describe 'SFSTransferWorker' do # rubocop:disable BlockLength
  before(:each) do
    @worker = TransferWorker::SFSTransferer.new
    @symlinked_data_path = File.join(File.dirname(__FILE__), 'resources', 'transfer_workers', 'symlink')
    @test_dest_root = File.join(File.dirname(__FILE__), 'resources', 'transfer_workers', 'dest')
    @depositor = 'RMC/RMA'
    @collection = 'RMA0001234'
    @msg = IngestMessage::SQSMessage.new(
      ingest_id: 'test_1234',
      data_path: @symlinked_data_path.to_s,
      dest_path: @test_dest_root.to_s,
      depositor: @depositor,
      collection: @collection
    )

    allow(FileUtils).to receive(:mkdir_p).with("#{@test_dest_root}/#{@depositor}/#{@collection}") { nil }
    allow(FileUtils).to receive(:mkdir).with("#{@test_dest_root}/#{@depositor}/#{@collection}/1") { nil }
    allow(FileUtils).to receive(:mkdir).with("#{@test_dest_root}/#{@depositor}/#{@collection}/2") { nil }
    allow(FileUtils).to receive(:mkdir).with("#{@test_dest_root}/#{@depositor}/#{@collection}/4") { nil }
    allow(FileUtils).to receive(:copy)
      .with("#{@symlinked_data_path}/#{@depositor}/#{@collection}/1/resource1.txt",
            "#{@test_dest_root}/#{@depositor}/#{@collection}/1/resource1.txt") { nil }
    allow(FileUtils).to receive(:copy)
      .with("#{@symlinked_data_path}/#{@depositor}/#{@collection}/2/resource2.txt",
            "#{@test_dest_root}/#{@depositor}/#{@collection}/2/resource2.txt") { nil }
    allow(FileUtils).to receive(:copy)
      .with("#{@symlinked_data_path}/#{@depositor}/#{@collection}/4/resource4.txt",
            "#{@test_dest_root}/#{@depositor}/#{@collection}/4/resource4.txt") { nil }
  end

  context 'when creating collection dir' do
    it 'skips if directory exists' do
      msg = IngestMessage::SQSMessage.new(
        ingest_id: 'test_1234',
        data_path: @symlinked_data_path.to_s,
        dest_path: @symlinked_data_path.to_s, # same dir as data_path so we know this directory exists
        depositor: @depositor,
        collection: @collection
      )
      path_to_trim = Pathname.new(@symlinked_data_path)
      @worker.create_collection_dir(msg, path_to_trim)
      expect(FileUtils).to have_received(:mkdir_p).exactly(0).times
    end

    it 'creates directory recursively if it does not exist' do
      path_to_trim = Pathname.new(@symlinked_data_path)
      @worker.create_collection_dir(@msg, path_to_trim)
      expect(FileUtils).to have_received(:mkdir_p).once
    end
  end

  context 'when processing path' do
    it 'skips if directory exists' do
      path = File.join(@symlinked_data_path, @depositor, @collection, '1')
      path_to_trim = Pathname.new(@symlinked_data_path)
      dest_root = @msg.data_path # same dir as data_dir so we know this directory exists
      @worker.process_path(path, path_to_trim, dest_root)
      expect(FileUtils).to have_received(:mkdir).exactly(0).times
    end

    it 'creates directory if does not exist' do
      path = File.join(@symlinked_data_path, @depositor, @collection, '1')
      path_to_trim = Pathname.new(@symlinked_data_path)
      dest_root = @msg.dest_path
      @worker.process_path(path, path_to_trim, dest_root)
      expect(FileUtils).to have_received(:mkdir).once
    end

    it 'copies file' do
      path = File.join(@symlinked_data_path, @depositor, @collection, '1', 'resource1.txt')
      path_to_trim = Pathname.new(@symlinked_data_path)
      dest_root = @msg.dest_path
      @worker.process_path(path, path_to_trim, dest_root)
      expect(FileUtils).to have_received(:copy).once
    end
  end

  context 'when generating destination path' do
    it 'takes relative portion of path and add it to destination root' do
      dest_root = '/a/'
      path = '/b/c/d/resource.txt'
      path_to_trim = Pathname.new('/b/c')
      expected_destination = '/a/d/resource.txt'
      expect(@worker.generate_dest_path(dest_root, path, path_to_trim)).to eq(expected_destination)
    end
  end

  context 'when generating destination path' do
    it 'combines relative path portion of the file to destination root directory' do
      dest_root_dir = '/dest'
      file_path = '/a/data/abc/resource.txt'
      path_to_trim = Pathname.new('/a/data')
      expected = '/dest/abc/resource.txt'
      expect(@worker.generate_dest_path(dest_root_dir, file_path, path_to_trim)).to eq(expected)
    end
  end

  context 'when working on directory containing symlinked directory' do
    it 'follows symlinks correctly' do
      expect(@worker.work(@msg)).to eq(true)

      expect(FileUtils).to have_received(:mkdir_p).once
      expect(FileUtils).to have_received(:mkdir).exactly(3).times
      expect(FileUtils).to have_received(:copy).exactly(3).times
    end
  end
end
