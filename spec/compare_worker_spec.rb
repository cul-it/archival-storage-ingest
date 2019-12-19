# frozen_string_literal:true

require 'spec_helper'
require 'rspec/mocks'
require 'aws-sdk-s3'
require 'archival_storage_ingest/manifests/manifest_of_manifests'
require 'archival_storage_ingest/messages/queues'
require 'archival_storage_ingest/workers/fixity_compare_worker'

RSpec.describe 'FixityCheckWorker' do # rubocop: disable Metrics/BlockLength
  subject(:worker) { FixityCompareWorker::ManifestComparator.new(s3_manager) }

  let(:s3_manager) do
    s3 = S3Manager.new('bogus_bucket')
    allow(s3).to receive(:manifest_key).and_call_original
    s3
  end

  let(:flat10) { File.open(resource('10ItemsFlat.json')) }
  let(:full10) { File.open(resource('10ItemsFull.json')) }
  let(:full10b) { File.open(resource('10ItemsFull.json')) }
  let(:flat10reordered) { File.open(resource('10ItemsReordered.json')) }
  let(:flat10error) { File.open(resource('10ItemsError.json')) }
  let(:flat9) { File.open(resource('9ItemsReordered.json')) }
  let(:ingest) { File.open(resource('10ItemsFull.json')) }

  let(:sfs_key) { '.manifest/test_1234_sfs.json' }
  let(:s3_key) { '.manifest/test_1234_s3.json' }
  let(:ingest_key) { '.manifest/test_1234_ingest_manifest.json' }

  let(:msg) do
    IngestMessage::SQSMessage.new(
      ingest_id: 'test_1234',
      depositor: 'MATH',
      collection: 'LecturesEvents'
    )
  end

  def resource(filename)
    File.join(File.dirname(__FILE__), ['resources', 'manifests', filename])
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

# Temporarily put this test here...
RSpec.describe 'ManifestOfManifests' do
  def resource(filename)
    File.join(File.dirname(__FILE__), ['resources', 'preingest', 'periodic_fixity', filename])
  end
  let(:man_of_mans) { resource('manifest_of_manifests.json') }
  context 'when finding manifest' do
    it 'returns manifest definition if corresponding depositor collection entry is found' do
      mom = Manifests::ManifestOfManifests.new(man_of_mans)
      man_def = mom.manifest_definition(depositor: 'test_depositor', collection: 'test_collection')
      expect(man_def.depositor).to eq('test_depositor')
    end
  end
end

RSpec.describe 'PeriodicFixityComparator' do # rubocop: disable Metrics/BlockLength
  let(:queuer) { spy('queuer') }
  let(:s3_bucket) { 'bogus_bucket' }
  let(:s3_manager) do
    s3 = S3Manager.new(s3_bucket)
    allow(s3).to receive(:manifest_key).and_call_original
    s3
  end
  let(:worker) do
    ticket_handler = spy('ticket_handler')
    ArchivalStorageIngest.configure do |config|
      config.queuer = queuer
      config.s3_manager = s3_manager
      config.message_queue_name = Queues::QUEUE_PERIODIC_FIXITY_COMPARISON
      config.in_progress_queue_name = Queues::QUEUE_PERIODIC_FIXITY_COMPARISON_IN_PROGRESS
      config.dest_queue_names = [Queues::QUEUE_COMPLETE]
      config.s3_bucket = s3_bucket
      config.debug = true
      config.develop = true
      config.ticket_handler = ticket_handler
    end
    manifest_dir = resource('manifests')
    man_of_mans = resource('manifest_of_manifests.json')
    periodic_fixity_root = resource('root')
    sfs_root = File.join(File.dirname(__FILE__), %w[resources preingest])
    FixityCompareWorker::PeriodicFixityComparator.new(
      s3_manager: s3_manager,
      manifest_dir: manifest_dir,
      man_of_mans: man_of_mans,
      periodic_fixity_root: periodic_fixity_root,
      sfs_root: sfs_root,
      relay_queue_name: Queues::QUEUE_PERIODIC_FIXITY
    )
  end
  let(:s3_col_man_key) { '.manifest/test_1234_s3.json' }
  let(:sfs_col_man_key) { '.manifest/test_1234_sfs.json' }
  let(:ingest_man_key) { '.manifest/test_1234_ingest_manifest.json' }
  let(:next_key) { 'test_depositor_next/test_collection_next/_EM_test_depositor_next_test_collection_next.json' }
  let(:next_dest_path) { File.join(worker.manifest_dir, '_EM_test_depositor_next_test_collection_next.json') }

  let(:msg) do
    IngestMessage::SQSMessage.new(
      ingest_id: 'test_1234',
      depositor: 'test_depositor',
      collection: 'test_collection'
    )
  end

  def resource(filename)
    File.join(File.dirname(__FILE__), ['resources', 'preingest', 'periodic_fixity', filename])
  end

  def source_data(filename)
    File.join(File.dirname(__FILE__), ['resources', 'preingest', 'source_data', filename])
  end

  def setup_manifest(man, key)
    allow(s3_manager).to receive(:retrieve_file).with(key).and_return(man)
  end

  def setup_next_manifest(man, key, dest_path)
    allow(s3_manager).to receive(:download_file).with(s3_key: key, dest_path: dest_path).and_return(man)
  end

  # rubocop: disable Metrics/AbcSize
  def setup_manifests
    manifest_to_use = '_EM_unmerged_new_collection_manifest.json'
    setup_manifest File.open(source_data(manifest_to_use)), s3_col_man_key
    setup_manifest File.open(source_data(manifest_to_use)), sfs_col_man_key
    setup_manifest File.open(source_data(manifest_to_use)), ingest_man_key
    setup_next_manifest File.open(source_data(manifest_to_use)), next_key, next_dest_path
    allow(s3_manager).to receive(:calculate_checksum).with(ingest_man_key)
                                                     .and_return(['eea594dee92e310255fd618e778889376b0cbf2a', 1175])
  end
  # rubocop: enable Metrics/AbcSize

  let(:dir_to_clean) do
    periodic_fixity_root = resource('root')
    File.join(periodic_fixity_root, 'test_depositor_next')
  end

  after(:each) do
    FileUtils.remove_dir(dir_to_clean)
  end

  context 'when completing successfully' do
    it 'queues next collection in man of mans for periodic fixity check' do
      setup_manifests
      worker.work(msg)

      expect(queuer).to have_received(:put_message).exactly(1).times
    end
  end
end
