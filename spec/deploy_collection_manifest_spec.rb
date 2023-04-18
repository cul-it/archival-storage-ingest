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
  let(:td_storage_manifest_path) do
    resolve_filename(%w[manifests test_depositor test_collection _EM_test_depositor_test_collection.json])
  end
  let(:td_ingest_manifest_path) do
    resolve_filename(%w[manifests test_depositor test_collection ingest_manifest.json])
  end
  let(:td2_storage_manifest_path) do
    resolve_filename(%w[manifests test_depositor_2 test_collection _EM_test_depositor_2_test_collection.json])
  end
  let(:td2_ingest_manifest_path) do
    resolve_filename(%w[manifests test_depositor_2 test_collection ingest_manifest.json])
  end
  let(:td_s3_key) { 'test_depositor/test_collection/_EM_test_depositor_test_collection.json' }
  let(:td2_s3_key) { 'test_depositor_2/test_collection/_EM_test_depositor_2_test_collection.json' }
  let(:arxiv_manifest_path) { resolve_filename(%w[manifests arXiv.json]) }
  let(:arxiv_s3_key) { 'arXiv/arXiv/arXiv.json' }
  let(:man_of_man_source) { resolve_filename(%w[manifests manifest_of_manifest.json]) }
  let(:man_of_man) { resolve_filename(%w[manifests manifest_of_manifest_copy.json]) }
  let(:old_manifest_sha1) { 'deadbeef' }
  let(:new_manifest_sha1) { '921d09399fdba978bb0863c98f372c9c211f8573' }
  let(:asif_bucket) { 's3-cular-invalid' }
  let(:s3_manager) do # rubocop: disable Metrics/BlockLength
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
      .with(any_args)
      .and_raise(IngestException, 'upload_file called with invalid arguments!')

    allow(s3m).to receive(:upload_file)
      .with(td_s3_key, td_storage_manifest_path) { true }

    allow(s3m).to receive(:upload_file)
      .with(td2_s3_key, td2_storage_manifest_path) { true }

    allow(s3m).to receive(:upload_file)
      .with(arxiv_s3_key, arxiv_manifest_path) { true }

    allow(s3m).to receive(:_upload_file)
      .with(bucket: asif_bucket, s3_key: td_s3_key, file: td_storage_manifest_path) { true }

    allow(s3m).to receive(:_upload_file)
      .with(bucket: asif_bucket, s3_key: td2_s3_key, file: td2_storage_manifest_path) { true }

    allow(s3m).to receive(:_upload_file)
      .with(bucket: asif_bucket, s3_key: arxiv_s3_key, file: arxiv_manifest_path) { true }

    s3m
  end
  let(:wasabi_manager) do # rubocop: disable Metrics/BlockLength
    s3m = S3Manager.new('bogus_bucket')

    allow(s3m).to receive(:s3) { s3m }

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
      .with(any_args)
      .and_raise(IngestException, 'upload_file called with invalid arguments!')

    allow(s3m).to receive(:upload_file)
      .with(td_s3_key, td_storage_manifest_path) { true }

    allow(s3m).to receive(:upload_file)
      .with(td2_s3_key, td2_storage_manifest_path) { true }

    allow(s3m).to receive(:upload_file)
      .with(arxiv_s3_key, arxiv_manifest_path) { true }

    allow(s3m).to receive(:_upload_file)
      .with(bucket: asif_bucket, s3_key: td_s3_key, file: td_storage_manifest_path) { true }

    allow(s3m).to receive(:_upload_file)
      .with(bucket: asif_bucket, s3_key: td2_s3_key, file: td2_storage_manifest_path) { true }

    allow(s3m).to receive(:_upload_file)
      .with(bucket: asif_bucket, s3_key: arxiv_s3_key, file: arxiv_manifest_path) { true }

    s3m
  end
  let(:ingest_date) { '2020-09-08' }
  let(:sfs_prefix) { File.join(File.dirname(__FILE__), 'resources', 'manifest_deployer') }
  let(:source_path) { File.join(File.dirname(__FILE__), 'resources', 'data', 'test_depositor', 'test_collection') }
  let(:file_identifier) do
    fi = Manifests::FileIdentifier.new(sfs_prefix: 'bogus')
    allow(fi).to receive(:identify_from_source).with(any_args) { 'text/plain' }
    allow(fi).to receive(:identify_from_storage).with(any_args) { 'text/plain' }
    fi
  end
  let(:manifest_validator) do
    storage_schema = resolve_filename(%w[schema manifest_schema_storage.json])
    ingest_schema = resolve_filename(%w[schema manifest_schema_ingest.json])
    Manifests::ManifestValidator.new(storage_schema: storage_schema, ingest_schema: ingest_schema)
  end

  before(:each) do
    FileUtils.cp(man_of_man_source, man_of_man)
    @deployer = Manifests::CollectionManifestDeployer.new(manifests_path: man_of_man, s3_manager: s3_manager,
                                                          manifest_validator: manifest_validator,
                                                          file_identifier: file_identifier,
                                                          sfs_prefix: sfs_prefix,
                                                          wasabi_manager: wasabi_manager)
    allow(FileUtils).to receive(:copy)
      .with(td_storage_manifest_path,
            '/cul/data/archivalxx/test_depositor/test_collection/_EM_test_depositor_test_collection.json') { nil }
    allow(FileUtils).to receive(:copy)
      .with(td2_storage_manifest_path,
            '/cul/data/archivalyy/test_depositor/test_collection/_EM_test_depositor_2_test_collection.json') { nil }
    allow(FileUtils).to receive(:copy)
      .with(arxiv_manifest_path,
            '/cul/data/archivalyy/arXiv/arXiv/arXiv.json') { nil }

    td_target = File.join(sfs_prefix, 'archivalxx', 'test_depositor', 'test_collection',
                          '_EM_test_depositor_test_collection.json')
    allow(FileUtils).to receive(:copy)
      .with(td_storage_manifest_path, td_target) { nil }
    td2_target = File.join(sfs_prefix, 'archivalyy', 'test_depositor_2', 'test_collection',
                           '_EM_test_depositor_2_test_collection.json')
    allow(FileUtils).to receive(:copy)
      .with(td2_storage_manifest_path, td2_target) { nil }
  end

  after(:each) do
    FileUtils.rm man_of_man
  end

  context 'when resolving manifest definition' do # rubocop: disable Metrics/BlockLength
    it 'returns definition if found' do
      manifest_params = Manifests::ManifestParameters.new(storage_manifest_path: td_storage_manifest_path,
                                                          ingest_manifest_path: td_ingest_manifest_path,
                                                          ingest_date: ingest_date)
      manifest_params.ingest_manifest.walk_packages do |package|
        package.source_path = source_path
      end
      manifest_def = @deployer.prepare_manifest_definition(manifest_parameters: manifest_params)
      expect(manifest_def.sha1).to eq(new_manifest_sha1)
    end

    it 'returns added definition when not found' do
      manifest_params = Manifests::ManifestParameters.new(storage_manifest_path: td2_storage_manifest_path,
                                                          ingest_manifest_path: td2_ingest_manifest_path,
                                                          ingest_date: ingest_date,
                                                          sfs: 'archivalyy')
      puts manifest_params.storage_manifest.depositor
      manifest_def = @deployer.prepare_manifest_definition(manifest_parameters: manifest_params)
      expect(manifest_def.sfs[0]).to eq('archivalyy')
    end

    it 'aborts if sfs is not supplied for new collection' do
      manifest_params = Manifests::ManifestParameters.new(storage_manifest_path: td2_storage_manifest_path,
                                                          ingest_manifest_path: td2_ingest_manifest_path,
                                                          ingest_date: ingest_date)
      expect do
        manifest_params = Manifests::ManifestParameters.new(storage_manifest_path: td2_storage_manifest_path,
                                                            ingest_manifest_path: td2_storage_manifest_path,
                                                            ingest_date: ingest_date)
        @deployer.prepare_manifest_definition(manifest_parameters: manifest_params)
      end.to raise_error(SystemExit)
    end
  end

  context 'when deploying collection manifest' do # rubocop: disable Metrics/BlockLength
    it 'updates sha1 of existing manifest definition' do
      mom = get_mom(man_of_man)
      expect(mom[0][:sha1]).to eq(old_manifest_sha1)
      manifest_params = Manifests::ManifestParameters.new(storage_manifest_path: td_storage_manifest_path,
                                                          ingest_manifest_path: td_ingest_manifest_path,
                                                          ingest_date: ingest_date)
      manifest_definition = @deployer.prepare_manifest_definition(manifest_parameters: manifest_params)
      @deployer.deploy_collection_manifest(manifest_def: manifest_definition,
                                           collection_manifest: td_storage_manifest_path)
      expect(s3_manager).to have_received(:upload_file).exactly(1).times
      mom = get_mom(man_of_man)
      expect(mom[0][:sha1]).to eq(new_manifest_sha1)
    end

    it 'adds new definition for new collection' do
      mom = get_mom(man_of_man)
      expect(mom.size).to eq(1)
      manifest_params = Manifests::ManifestParameters.new(storage_manifest_path: td2_storage_manifest_path,
                                                          ingest_manifest_path: td2_ingest_manifest_path,
                                                          ingest_date: ingest_date,
                                                          sfs: 'archivalyy')
      manifest_definition = @deployer.prepare_manifest_definition(manifest_parameters: manifest_params)
      @deployer.deploy_collection_manifest(manifest_def: manifest_definition,
                                           collection_manifest: td2_storage_manifest_path)
      expect(s3_manager).to have_received(:upload_file).exactly(1).times
      mom = get_mom(man_of_man)
      expect(mom.size).to eq(2)
      expect(mom[1][:sfs][0]).to eq('archivalyy')
    end
  end
end
