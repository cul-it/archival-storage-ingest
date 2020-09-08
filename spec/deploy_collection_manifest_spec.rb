# frozen_string_literal: true

require 'rspec'

require 'archival_storage_ingest/manifests/deploy_collection_manifest'
require 'archival_storage_ingest/manifests/manifests'
require 'fileutils'
require 'json'

def resolve_filename(path_array)
  File.join(File.dirname(__FILE__), 'resources', path_array)
end

def get_mom(mom)
  f = File.open(mom, 'r')
  mom_text = f.read
  f.close
  JSON.parse(mom_text, symbolize_names: true)
end

RSpec.describe 'CollectionManifestDeployer' do # rubocop: disable Metrics/BlockLength
  let(:td_manifest_path) { resolve_filename(%w[manifests test_depositor test_collection _EM_test_depositor_test_collection.json]) }
  let(:td_s3_key) { 'test_depositor/test_collection/_EM_test_depositor_test_collection.json' }
  let(:arxiv_manifest_path) { resolve_filename(%w[manifests arXiv.json]) }
  let(:arxiv_s3_key) { 'arXiv/arXiv/arXiv.json' }
  let(:man_of_man_source) { resolve_filename(%w[manifests manifest_of_manifest.json]) }
  let(:man_of_man) { resolve_filename(%w[manifests manifest_of_manifest_copy.json]) }
  let(:old_manifest_sha1) { 'deadbeef' }
  let(:new_manifest_sha1) { '3e9e7777b9e84f3b51c123f823eff0423a4aa568' }
  let(:s3_manager) do
    s3m = S3Manager.new('bogus_bucket')

    allow(s3m).to receive(:upload_string)
      .with(any_args)
      .and_raise(IngestException, 'upload_string must not be called in this test!')

    allow(s3m).to receive(:list_object_keys)
      .with(any_args)
      .and_raise(IngestException, 'list_object_keys must not be called in this test!')

    allow(s3m).to receive(:calculate_checksum)
      .with(any_args)
      .and_raise(IngestException, 'calculate_checksum must not be called in this test!')

    # This is harmless.
    allow(s3m).to receive(:manifest_key).with(any_args).and_call_original

    allow(s3m).to receive(:retrieve_file)
      .with(any_args)
      .and_raise(IngestException, 'retrieve_file must not be called in this test!')

    allow(s3m).to receive(:upload_file)
      .with(td_s3_key, td_manifest_path) { true }

    allow(s3m).to receive(:upload_file)
      .with(arxiv_s3_key, arxiv_manifest_path) { true }

    s3m
  end
  let(:ingest_date) { '2020-09-08' }

  before(:each) do
    FileUtils.cp(man_of_man_source, man_of_man)
    @deployer = Manifests::CollectionManifestDeployer.new(manifests_path: man_of_man, s3_manager: s3_manager)
    allow(FileUtils).to receive(:copy)
      .with(td_manifest_path,
            '/cul/data/archivalxx/test_depositor/test_collection/_EM_test_depositor_test_collection.json') { nil }
    allow(FileUtils).to receive(:copy)
      .with(arxiv_manifest_path,
            '/cul/data/archivalyy/arXiv/arXiv/arXiv.json') { nil }
  end

  after(:each) do
    FileUtils.rm man_of_man
  end

  context 'when resolving manifest definition' do
    it 'returns definition if found' do
      manifest_def = @deployer.prepare_manifest_definition(collection_manifest: td_manifest_path,
                                                           ingest_manifest: td_manifest_path,
                                                           ingest_date: ingest_date)
      expect(manifest_def[:sha1]).to eq(new_manifest_sha1)
    end

    it 'returns added definition when not found' do
      arxiv_manifest = resolve_filename(%w[manifests arXiv.json])
      manifest_def = @deployer.prepare_manifest_definition(collection_manifest: arxiv_manifest,
                                                           ingest_manifest: arxiv_manifest,
                                                           ingest_date: ingest_date,
                                                           sfs: 'archivalyy')
      expect(manifest_def[:sfs][0]).to eq('archivalyy')
    end

    it 'aborts if sfs is not supplied for new collection' do
      arxiv_manifest = resolve_filename(%w[manifests arXiv.json])
      expect do
        @deployer.prepare_manifest_definition(collection_manifest: arxiv_manifest,
                                              ingest_manifest: arxiv_manifest,
                                              ingest_date: ingest_date)
      end.to raise_error(SystemExit)
    end
  end

  context 'when deploying collection manifest' do
    it 'updates sha1 of existing manifest definition' do
      mom = get_mom(man_of_man)
      expect(mom[0][:sha1]).to eq(old_manifest_sha1)
      manifest_definition = @deployer.prepare_manifest_definition(collection_manifest: td_manifest_path,
                                                                  ingest_manifest: td_manifest_path,
                                                                  ingest_date: ingest_date)
      @deployer.deploy_collection_manifest(manifest_def: manifest_definition, collection_manifest: td_manifest_path)
      expect(s3_manager).to have_received(:upload_file).exactly(1).times
      mom = get_mom(man_of_man)
      expect(mom[0][:sha1]).to eq(new_manifest_sha1)
    end

    it 'adds new definition for new collection' do
      mom = get_mom(man_of_man)
      expect(mom.size).to eq(1)
      manifest_definition = @deployer.prepare_manifest_definition(collection_manifest: arxiv_manifest_path,
                                                                  ingest_manifest: arxiv_manifest_path,
                                                                  ingest_date: ingest_date,
                                                                  sfs: 'archivalyy')
      @deployer.deploy_collection_manifest(manifest_def: manifest_definition, collection_manifest: arxiv_manifest_path)
      expect(s3_manager).to have_received(:upload_file).exactly(1).times
      mom = get_mom(man_of_man)
      expect(mom.size).to eq(2)
      expect(mom[1][:sfs][0]).to eq('archivalyy')
    end
  end
end
