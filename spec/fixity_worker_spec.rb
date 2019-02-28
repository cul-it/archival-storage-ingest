# frozen_string_literal: true

require 'rspec'
require 'spec_helper'
require 'json'
require 'stringio'
require 'archival_storage_ingest/s3/s3_manager'
require 'archival_storage_ingest/workers/fixity_worker'
require 'archival_storage_ingest/workers/worker'

RSpec.describe 'FixityWorker' do # rubocop:disable BlockLength
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
  let(:expected_old_hash) do
    {
      "#{depositor}/#{collection}" => {
        items: {
          '1/one.zip' => {
            sha1: 'c19ed993b201bd33b3765c3f6ec59bd39f995629'
          },
          '2/two.zip' => {
            sha1: '86c6167b8a8245a699a5735a3c56890421c28689'
          }
        }
      }
    }
  end
  let(:s3_manager) do
    s3m = S3Manager.new('bogus_bucket')

    allow(s3m).to receive(:upload_string)
      .with(".manifest/#{ingest_id}_s3.json", expected_old_hash.to_json) { true }
    # .with(".manifest/#{ingest_id}_s3.json", expected_hash.to_json) { true }

    allow(s3m).to receive(:upload_string)
      .with(".manifest/#{ingest_id}_sfs.json", expected_old_hash.to_json) { true }
    # .with(".manifest/#{ingest_id}_sfs.json", expected_hash.to_json) { true }

    allow(s3m).to receive(:upload_file)
      .with(any_args)
      .and_raise(IngestException, 'upload_file must not be called in this test!')

    allow(s3m).to receive(:list_object_keys)
      .with("#{depositor}/#{collection}") do
      %W[
        #{depositor}/#{collection}/1/one.zip
        #{depositor}/#{collection}/2/two.zip
      ]
    end

    allow(s3m).to receive(:calculate_checksum)
      .with("#{depositor}/#{collection}/1/one.zip") { 'c19ed993b201bd33b3765c3f6ec59bd39f995629' }

    allow(s3m).to receive(:calculate_checksum)
      .with("#{depositor}/#{collection}/2/two.zip") { '86c6167b8a8245a699a5735a3c56890421c28689' }

    allow(s3m).to receive(:manifest_key).with(any_args).and_call_original
    ingest_manifest_s3_key = s3m.manifest_key(ingest_id, Workers::TYPE_INGEST)
    ingest_manifest = StringIO.new(expected_old_hash.to_json)
    allow(s3m).to receive(:retrieve_file)
      .with(ingest_manifest_s3_key) { ingest_manifest }

    s3m
  end

  describe 'IngestS3FixityGenerator' do
    let(:worker) { FixityWorker::IngestFixityS3Generator.new(s3_manager) }

    context 'when doing work' do
      it 'should upload manifest' do
        expect(worker.work(msg)).to eq(true)

        expect(s3_manager).to have_received(:upload_string).once
      end
    end

    context 'when generating manifest' do
      it 'returns manifest' do
        manifest = worker.generate_manifest(msg)
        # expect(manifest.manifest_hash).to eq(expected_old_hash)
        expect(manifest.to_old_manifest(depositor, collection)).to eq(expected_old_hash)
      end
    end
  end

  describe 'IngestSFSFixityGenerator' do
    let(:worker) { FixityWorker::IngestFixitySFSGenerator.new(s3_manager) }

    context 'when doing work' do
      it 'should upload manifest' do
        expect(worker.work(msg)).to eq(true)

        expect(s3_manager).to have_received(:upload_string).once
      end
    end

    context 'when generating manifest' do
      it 'returns manifest' do
        manifest = worker.generate_manifest(msg)
        # expect(manifest.manifest_hash).to eq(expected_hash)
        expect(manifest.to_old_manifest(depositor, collection)).to eq(expected_old_hash)
      end
    end

    context 'when calculating checksum' do
      it 'should return checksum hex' do
        sha1 = worker.calculate_checksum("#{depositor}/#{collection}/1/one.zip", msg)
        expect(sha1).to eq('c19ed993b201bd33b3765c3f6ec59bd39f995629')
      end
    end
  end
end
