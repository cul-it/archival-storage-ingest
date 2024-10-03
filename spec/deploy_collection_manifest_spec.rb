# frozen_string_literal: true

require 'rspec'

require 'archival_storage_ingest/manifests/deploy_collection_manifest'
require 'archival_storage_ingest/manifests/manifests'
require 'archival_storage_ingest/s3/local_manager'
require 'fileutils'
require 'json'

RESOURCE_ROOT = File.join(File.dirname(__FILE__), 'resources')

def resolve_filename(path_array)
  File.join(RESOURCE_ROOT, path_array)
end

def get_mom(mom)
  f = File.open(mom, 'r')
  mom_text = f.read
  f.close
  JSON.parse(mom_text, symbolize_names: true)
end

RSpec.describe 'CollectionManifestDeployer' do
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
  let(:new_manifest_sha1) { 'c0c0af5c300491abde9aa8a8678d44bf99c90121' }
  let(:asif_bucket) { 's3-cular-invalid' }
  let(:s3_manager) do
    local_root = File.join(File.dirname(__FILE__), 'resources', 'cloud')
    LocalManager.new(local_root:, type: TYPE_S3)
  end
  let(:s3_west_manager) do
    local_root = File.join(File.dirname(__FILE__), 'resources', 'cloud')
    LocalManager.new(local_root:, type: TYPE_S3_WEST)
  end
  let(:wasabi_manager) do
    local_root = File.join(File.dirname(__FILE__), 'resources', 'cloud')
    LocalManager.new(local_root:, type: TYPE_WASABI)
  end
  let(:manifest_storage_manager) do
    local_root = File.join(File.dirname(__FILE__), 'resources', 'cloud')
    LocalManager.new(local_root:, type: TYPE_VERSIONED_MANIFEST)
  end
  let(:ingest_date) { '2020-09-08' }
  # sfs_prefix is still used as temporary storage for the collection manifests
  let(:sfs_prefix) { File.join(File.dirname(__FILE__), 'resources', 'manifests', 'manifest_deployer', 'sfs') }
  let(:source_path) { File.join(File.dirname(__FILE__), 'resources', 'data', 'test_depositor', 'test_collection') }
  let(:file_identifier) do
    fi = Manifests::FileIdentifier.new
    allow(fi).to receive(:identify_from_source).with(any_args).and_return('text/plain')
    fi
  end
  let(:manifest_validator) do
    storage_schema = resolve_filename(%w[schema manifest_schema_storage.json])
    ingest_schema = resolve_filename(%w[schema manifest_schema_ingest.json])
    Manifests::ManifestValidator.new(storage_schema:, ingest_schema:)
  end

  before(:each) do
    FileUtils.cp(man_of_man_source, man_of_man)
    FileUtils.mkdir_p File.join(sfs_prefix, 'archivalxx', 'test_depositor', 'test_collection')
    FileUtils.mkdir_p File.join(sfs_prefix, 'archivalyy', 'test_depositor_2', 'test_collection')
    @deployer = Manifests::CollectionManifestDeployer.new(
      manifests_path: man_of_man, s3_manager:, s3_west_manager:, manifest_validator:,
      file_identifier:, wasabi_manager:, manifest_storage_manager:
    )
  end

  after(:each) do
    FileUtils.rm man_of_man
    [s3_manager, s3_west_manager, wasabi_manager, manifest_storage_manager].each do |manager|
      manager.cleanup
    end
    FileUtils.rm_rf(sfs_prefix, secure: true) if File.directory? sfs_prefix
  end

  context 'when resolving manifest definition' do
    it 'returns definition if found' do
      manifest_params = Manifests::ManifestParameters.new(storage_manifest_path: td_storage_manifest_path,
                                                          ingest_manifest_path: td_ingest_manifest_path,
                                                          ingest_date:)
      manifest_params.ingest_manifest.walk_packages do |package|
        package.source_path = source_path
      end
      manifest_def = @deployer.prepare_manifest_definition(manifest_parameters: manifest_params)
      expect(manifest_def.sha1).to eq(new_manifest_sha1)
    end

    it 'returns added definition when not found' do
      manifest_params = Manifests::ManifestParameters.new(storage_manifest_path: td2_storage_manifest_path,
                                                          ingest_manifest_path: td2_ingest_manifest_path,
                                                          ingest_date:)
      puts manifest_params.storage_manifest.depositor
      manifest_def = @deployer.prepare_manifest_definition(manifest_parameters: manifest_params)
      expect(manifest_def.s3_key).to eq('test_depositor_2/test_collection/_EM_test_depositor_2_test_collection.json')
    end
  end

  context 'when deploying collection manifest' do
    it 'updates sha1 of existing manifest definition' do
      mom = get_mom(man_of_man)
      expect(mom[0][:sha1]).to eq(old_manifest_sha1)
      manifest_params = Manifests::ManifestParameters.new(storage_manifest_path: td_storage_manifest_path,
                                                          ingest_manifest_path: td_ingest_manifest_path,
                                                          ingest_date:)
      manifest_definition = @deployer.prepare_manifest_definition(manifest_parameters: manifest_params)
      @deployer.deploy_collection_manifest(manifest_def: manifest_definition,
                                           collection_manifest: td_storage_manifest_path)
      expected_file = File.join(File.dirname(__FILE__), 'resources', 'cloud', TYPE_S3, 'test_depositor', 
                                'test_collection', '_EM_test_depositor_test_collection.json')
      expect(File.file? expected_file).to be_truthy
      mom = get_mom(man_of_man)
      expect(mom[0][:sha1]).to eq(new_manifest_sha1)
    end

    it 'adds new definition for new collection' do
      mom = get_mom(man_of_man)
      expect(mom.size).to eq(1)
      manifest_params = Manifests::ManifestParameters.new(storage_manifest_path: td2_storage_manifest_path,
                                                          ingest_manifest_path: td2_ingest_manifest_path,
                                                          ingest_date:)
      manifest_definition = @deployer.prepare_manifest_definition(manifest_parameters: manifest_params)
      @deployer.deploy_collection_manifest(manifest_def: manifest_definition,
                                           collection_manifest: td2_storage_manifest_path)
      expected_file = File.join(File.dirname(__FILE__), 'resources', 'cloud', TYPE_S3, 'test_depositor_2',
                                'test_collection', '_EM_test_depositor_2_test_collection.json')
      expect(File.file? expected_file).to be_truthy
      mom = get_mom(man_of_man)
      expect(mom.size).to eq(2)
    end
  end
end
