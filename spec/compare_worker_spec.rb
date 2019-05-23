# frozen_string_literal:true

require 'spec_helper'
require 'rspec/mocks'
require 'aws-sdk-s3'
require 'archival_storage_ingest/workers/fixity_compare_worker'

def resource(filename)
  File.join(File.dirname(__FILE__), ['resources', 'manifests', filename])
end

RSpec.describe 'FixityCheckWorker' do # rubocop: disable Metrics/BlockLength
  subject(:worker) { FixityCompareWorker::ManifestComparator.new(s3_manager) }

  let(:s3_manager) do
    s3 = S3Manager.new('bogus_bucket')
    allow(s3).to receive(:manifest_key).and_call_original
    s3
  end

  let(:flat10) { File.open(resource('10ItemsShaOnly.new.json')) }
  let(:full10) { File.open(resource('10ItemsFull.new.json')) }
  let(:full10b) { File.open(resource('10ItemsFull.new.json')) }
  let(:flat10reordered) { File.open(resource('10ItemsShaOnlyReordered.new.json')) }
  let(:flat10error) { File.open(resource('10ItemsShaOnlyError.json.new')) }
  let(:flat9) { File.open(resource('9ItemsShaOnlyReordered.json.new')) }
  let(:ingest) { File.open(resource('10ItemsFull.new.json')) }

  let(:sfs_key) { '.manifest/test_1234_sfs.json' }
  let(:s3_key) { '.manifest/test_1234_s3.json' }
  let(:ingest_key) { '.manifest/test_1234_ingest_manifest.json' }

  let(:msg) do
    IngestMessage::SQSMessage.new(
      ingest_id: 'test_1234',
      data_path: ''
    )
  end

  def setup_manifest(man, key)
    if man.nil?
      allow(s3_manager).to receive(:retrieve_file).with(key).and_raise(Aws::S3::Errors::NoSuchKey.new('context', 'no manifest'))
    else
      allow(s3_manager).to receive(:retrieve_file).with(key).and_return(man)
    end
  end

  def setup_manifests(s3_manifest, sfs_manifest)
    setup_manifest s3_manifest, s3_key
    setup_manifest sfs_manifest, sfs_key
    setup_manifest ingest, ingest_key
  end

  context 'when called with manifests not completed' do
    it 'no s3 diff makes it exit with a false result' do
      setup_manifests(nil, nil)

      expect(worker.work(msg)).to be_falsey
    end
    it 'no sfs diff makes it exit with a false result' do
      setup_manifests(full10, nil)

      expect(worker.work(msg)).to be_falsey
      expect(s3_manager).to have_received(:retrieve_file).with('.manifest/test_1234_s3.json')
      expect(s3_manager).to have_received(:retrieve_file).with('.manifest/test_1234_sfs.json')
    end
  end

  context 'when called with two matching manifests' do
    it 'returns true for identical manifests' do
      setup_manifests(full10, full10b)

      expect(worker.work(msg)).to be_truthy
    end

    it 'returns true for flat and non-flat manifests' do
      setup_manifests(full10, flat10)

      expect(worker.work(msg)).to be_truthy
    end

    it 'returns true for differently-ordered manifests' do
      setup_manifests(flat10, flat10reordered)

      expect(worker.work(msg)).to be_truthy
    end
  end

  context 'when called with non-matching manifests' do
    it 'throws exception if SFS manifest short' do
      setup_manifests(flat10, flat9)

      exception = nil
      expect { worker.work(msg) }.to(raise_error { |ex| exception = ex })

      expect(exception).to be_instance_of(IngestException)
      expect(exception.message).to start_with('Ingest and SFS manifests do not match:')
    end

    it 'throws exception if S3 manifest short' do
      setup_manifests(flat9, flat10)

      exception = nil
      expect { worker.work(msg) }.to(raise_error { |ex| exception = ex })

      expect(exception).to be_instance_of(IngestException)
      expect(exception.message).to start_with('Ingest and S3 manifests do not match')
    end

    it 'throws exception if Ingest and SFS manifests have different SHAs' do
      setup_manifests(full10, flat10error)

      exception = nil
      expect { worker.work(msg) }.to(raise_error { |ex| exception = ex })

      expect(exception).to be_instance_of(IngestException)
      expect(exception.message).to start_with('Ingest and SFS manifests do not match')
    end
  end
end
