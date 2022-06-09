# frozen_string_literal: true

require 'rspec'
require 'spec_helper'
require 'json'
require 'stringio'
require 'archival_storage_ingest/s3/s3_manager'
require 'archival_storage_ingest/workers/fixity_worker'
require 'archival_storage_ingest/workers/worker'

# TODO: Refactor tests so that variables are defined locally to their use as much as possible.
RSpec.describe 'FixityWorker' do # rubocop:disable Metrics/BlockLength
  let(:manifest_dir) { File.join(File.dirname(__FILE__), 'resources', 'fixity_workers', 'manifest') }
  let(:job_id) { 'test_1234' }
  let(:depositor) { 'RMC/RMA' }
  let(:collection) { 'RMA0123' }
  let(:dest_path) { File.join(File.dirname(__FILE__), 'resources', 'fixity_workers', 'sfs', 'archival01', depositor, collection) }
  let(:msg) do
    IngestMessage::SQSMessage.new(
      job_id: job_id,
      dest_path: dest_path.to_s,
      depositor: depositor,
      collection: collection
    )
  end
  let(:expected_old_ingest_hash) do
    {
      "#{depositor}/#{collection}" => {
        items: {
          '1/one.zip' => {
            sha1: 'c19ed993b201bd33b3765c3f6ec59bd39f995629', size: 168
          },
          '2/two.zip' => {
            sha1: '86c6167b8a8245a699a5735a3c56890421c28689', size: 168
          }
        }
      }
    }
  end
  let(:ingest_manifest_hash) do
    {
      collection_id: collection,
      depositor: depositor,
      number_packages: 1,
      packages: [
        {
          package_id: FixityWorker::FIXITY_TEMPORARY_PACKAGE_ID,
          files: [
            {
              filepath: '1/one.zip',
              sha1: 'c19ed993b201bd33b3765c3f6ec59bd39f995629',
              size: 168
            },
            {
              filepath: '2/two.zip',
              sha1: '86c6167b8a8245a699a5735a3c56890421c28689',
              size: 168
            }
          ]
        }
      ]
    }
  end
  let(:fixity_manifest_hash) do
    {
      packages: [
        {
          package_id: FixityWorker::FIXITY_TEMPORARY_PACKAGE_ID,
          files: [
            {
              filepath: '1/one.zip',
              sha1: 'c19ed993b201bd33b3765c3f6ec59bd39f995629',
              size: 168
            },
            {
              filepath: '2/two.zip',
              sha1: '86c6167b8a8245a699a5735a3c56890421c28689',
              size: 168
            }
          ]
        }
      ]
    }
  end
  let(:periodic_fixity_manifest_hash) do
    {
      packages: [
        {
          package_id: FixityWorker::FIXITY_TEMPORARY_PACKAGE_ID,
          files: [
            {
              filepath: '1/one.zip',
              sha1: 'c19ed993b201bd33b3765c3f6ec59bd39f995629',
              size: 168
            },
            {
              filepath: '2/two.zip',
              sha1: '86c6167b8a8245a699a5735a3c56890421c28689',
              size: 168
            },
            {
              filepath: '3/two.zip',
              sha1: '86c6167b8a8245a699a5735a3c56890421c28689',
              size: 168
            }
          ]
        }
      ]
    }
  end
  let(:s3_manager) do
    s3m = S3Manager.new('bogus_bucket')

    allow(s3m).to receive(:upload_string)
      .with(".manifest/#{job_id}_s3.json", fixity_manifest_hash.to_json) { true }
    # .with(".manifest/#{job_id}_s3.json", expected_hash.to_json) { true }

    allow(s3m).to receive(:upload_string)
      .with(".manifest/#{job_id}_sfs.json", fixity_manifest_hash.to_json) { true }
    # .with(".manifest/#{job_id}_sfs.json", expected_hash.to_json) { true }

    allow(s3m).to receive(:upload_file)
      .with(any_args)
      .and_raise(IngestException, 'upload_file must not be called in this test!')

    # Ingest manifest should only return one and two.
    # The list_object_keys will return one, two and three.
    # It will be an error if ingest fixity check requests three.
    allow(s3m).to receive(:list_object_keys)
      .with("#{depositor}/#{collection}/") do
      %W[
        #{depositor}/#{collection}/1/one.zip
        #{depositor}/#{collection}/2/two.zip
        #{depositor}/#{collection}/3/two.zip
      ]
    end

    allow(s3m).to receive(:calculate_checksum)
      .with("#{depositor}/#{collection}/1/one.zip") { ['c19ed993b201bd33b3765c3f6ec59bd39f995629', 168] }

    allow(s3m).to receive(:calculate_checksum)
      .with("#{depositor}/#{collection}/2/two.zip") { ['86c6167b8a8245a699a5735a3c56890421c28689', 168] }

    allow(s3m).to receive(:manifest_key).with(any_args).and_call_original
    ingest_manifest_s3_key = s3m.manifest_key(job_id, Workers::TYPE_INGEST)
    ingest_manifest = StringIO.new(ingest_manifest_hash.to_json)
    allow(s3m).to receive(:retrieve_file)
      .with(ingest_manifest_s3_key) { ingest_manifest }

    s3m
  end

  let(:application_logger) { spy('application_logger') }

  describe 'IngestS3FixityGenerator' do # rubocop:disable Metrics/BlockLength
    let(:worker) do
      ArchivalStorageIngest.configure do |config|
        config.logger = Logger.new($stdout)
        config.worker = FixityWorker::IngestFixityS3Generator.new(application_logger, s3_manager)
      end
      ArchivalStorageIngest.configuration.worker
    end

    context 'when doing work' do
      it 'should upload manifest' do
        expect(worker.work(msg)).to eq(true)

        expect(s3_manager).to have_received(:upload_string).once
      end
    end

    context 'when generating manifest' do
      it 'returns manifest for objects in ingest manifest' do
        manifest = worker.generate_manifest(msg)
        expect(manifest.to_json_fixity).to eq(fixity_manifest_hash.to_json)
      end
    end

    context 'when generating periodic manifest' do
      it 'returns manifest for objects in s3 listing' do
        allow(s3_manager).to receive(:calculate_checksum)
          .with("#{depositor}/#{collection}/3/two.zip") { ['86c6167b8a8245a699a5735a3c56890421c28689', 168] }
        periodic_worker = FixityWorker::PeriodicFixityS3Generator.new(application_logger, s3_manager)
        manifest = periodic_worker.generate_manifest(msg)
        expect(manifest.to_json_fixity).to eq(periodic_fixity_manifest_hash.to_json)
      end
    end
  end

  describe 'IngestSFSFixityGenerator' do # rubocop:disable Metrics/BlockLength
    let(:worker) do
      ArchivalStorageIngest.configure do |config|
        config.logger = Logger.new($stdout)
        config.worker = FixityWorker::IngestFixityS3Generator.new(application_logger, s3_manager)
      end
      ArchivalStorageIngest.configuration.worker
    end

    context 'when doing work' do
      it 'should upload manifest' do
        expect(worker.work(msg)).to eq(true)

        expect(s3_manager).to have_received(:upload_string).once
      end
    end

    context 'when generating manifest' do
      it 'returns manifest for objects in ingest manifest' do
        manifest = worker.generate_manifest(msg)
        expect(manifest.to_json_fixity).to eq(fixity_manifest_hash.to_json)
      end
    end

    context 'when calculating checksum' do
      it 'should return checksum hex' do
        (sha1, size) = worker.calculate_checksum('1/one.zip', msg)
        expect(sha1).to eq('c19ed993b201bd33b3765c3f6ec59bd39f995629')
        expect(size).to eq(168)
      end
    end

    context 'when generating periodic sfs manifest' do
      it 'returns manifest for all objects' do
        periodic_worker = FixityWorker::PeriodicFixitySFSGenerator.new(application_logger, s3_manager)
        manifest = periodic_worker.generate_manifest(msg)
        expect(manifest.to_json_fixity).to eq(fixity_manifest_hash.to_json)
      end
    end

    context 'when generating periodic sfs manifest with split archival buckets' do
      it 'returns manifest for all objects in all of the split archival buckets' do
        second_dest_path = File.join(File.dirname(__FILE__), 'resources',
                                     'fixity_workers', 'sfs', 'archival02', depositor, collection)
        periodic_msg = IngestMessage::SQSMessage.new(
          job_id: job_id,
          dest_path: "#{dest_path},#{second_dest_path}",
          depositor: depositor,
          collection: collection
        )
        periodic_worker = FixityWorker::PeriodicFixitySFSGenerator.new(application_logger, s3_manager)
        manifest = periodic_worker.generate_manifest(periodic_msg)
        expect(manifest.to_json_fixity).to eq(periodic_fixity_manifest_hash.to_json)
      end
    end
  end
end
