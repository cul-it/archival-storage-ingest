# frozen_string_literal: true

require 'rspec'
require 'spec_helper'
require 'json'
require 'archival_storage_ingest/s3/s3_manager'

RSpec.describe 'SFSFixityGenerator' do # rubocop:disable BlockLength
  let(:dest_path) { File.join(File.dirname(__FILE__), 'resources', 'fixity_workers', 'sfs', 'archival01') }
  let(:manifest_dir) { File.join(File.dirname(__FILE__), 'resources', 'fixity_workers', 'manifest') }
  let(:ingest_id) { 'test_1234' }
  let(:depositor) { 'RMC/RMA' }
  let(:collection) { 'RMA0123' }
  let(:msg) do
    IngestMessage::SQSMessage.new(
      ingest_id: ingest_id,
      dest_path: dest_path.to_s,
      manifest_dir: manifest_dir,
      depositor: depositor,
      collection: collection
    )
  end
  let(:expected_hash) do
    {
      number_files: 2,
      files: [
        {
          filepath: "#{depositor}/#{collection}/1/one.zip",
          sha1: 'c19ed993b201bd33b3765c3f6ec59bd39f995629'
        },
        {
          filepath: "#{depositor}/#{collection}/2/two.zip",
          sha1: '86c6167b8a8245a699a5735a3c56890421c28689'
        }
      ]
    }
  end
  let(:s3_manager) do
    s3m = S3Manager.new('bogus_bucket')
    allow(s3m).to receive(:upload_string)
      .with(".manifest/#{ingest_id}_s3.json", expected_hash.to_json) { true }
    allow(s3m).to receive(:upload_string)
      .with(".manifest/#{ingest_id}_sfs.json", expected_hash.to_json) { true }
    allow(s3m).to receive(:upload_file)
      .with(any_args)
      .and_raise(IngestException, 'upload_file must not be called in this test!')
    s3m
  end
  let(:worker) { FixityWorker::SFSFixityGenerator.new(s3_manager) }

  context 'when doing work' do
    it 'should generate manifest' do
      expect(worker.work(msg)).to eq(true)

      expect(s3_manager).to have_received(:upload_string).once
    end
  end

  context 'when generating manifest' do
    it 'returns manifest' do
      manifest = worker.generate_manifest(msg)
      expect(manifest.manifest_hash).to eq(expected_hash)
    end
  end

  context 'when calculating checksum' do
    it 'should return sha1 hex' do
      sha1 = worker.calculate_sha1("#{dest_path}/#{depositor}/#{collection}/1/one.zip")
      expect(sha1).to eq('c19ed993b201bd33b3765c3f6ec59bd39f995629')
    end
  end
end
