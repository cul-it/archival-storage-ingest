# frozen_string_literal: true

require 'archival_storage_ingest/ingest_utils/ingest_params'
require 'archival_storage_ingest/manifests/manifests'
require 'archival_storage_ingest/preingest/ingest_env_initializer'
require 'archival_storage_ingest/s3/local_manager'

require 'fileutils'
require 'json_schemer'
require 'rspec'
require 'yaml'

class TestIngestParams < IngestUtils::IngestParams
  def update_ingest_manifest(manifest_file)
    @ingest_manifest = manifest_file
  end

  def update_collection_manifest(manifest_file)
    @existing_storage_manifest = manifest_file
  end

  def update_asset_source(asset_source)
    @asset_source = asset_source
  end
end

RSpec.describe 'IngestEnvInitializer' do
  let(:depositor) { 'test_depositor' }
  let(:collection) { 'test_collection' }
  let(:base_dir) { File.dirname(__FILE__) }

  let(:ingest_root) { File.join(base_dir, 'resources', 'preingest', 'ingest_root') }
  let(:source_data) { File.join(base_dir, 'resources', 'preingest', 'source_data') }
  let(:storage_manifest_filename) { '_EM_test_depositor_test_collection.json' }
  let(:storage_manifest) { File.join(source_data, '_EM_collection_manifest.json') }
  let(:ingest_manifest) { File.join(source_data, '_EM_ingest_manifest.json') }
  let(:merged_manifest) { File.join(source_data, '_EM_merged_collection_manifest.json') }
  let(:expected_ingest_config) { File.join(source_data, 'expected_ingest_config.yaml') }
  let(:data) { File.join(source_data, depositor, collection) }
  let(:ticket_id) { 'CULAR-xxxx' }
  let(:dir_to_clean) { File.join(ingest_root, depositor) }
  let(:storage_schema) { File.join(base_dir, 'resources', 'schema', 'manifest_schema_storage.json') }
  let(:ingest_schema) { File.join(base_dir, 'resources', 'schema', 'manifest_schema_ingest.json') }
  let(:manifest_validator) { Manifests::ManifestValidator.new(ingest_schema:, storage_schema:) }
  let(:file_identifier) do
    fi = Manifests::FileIdentifier.new
    allow(fi).to receive(:identify_from_source).with(any_args).and_return('text/plain')
    fi
  end
  let(:ingest_params_path) { File.join(source_data, 'ingest.conf') }
  let(:ingest_params) do
    ingest_params = TestIngestParams.new(ingest_params_path)
    ingest_params.update_ingest_manifest(ingest_manifest)
    ingest_params.update_collection_manifest(storage_manifest_filename)
    ingest_params.update_asset_source(data)
    ingest_params
  end
  let(:wasabi_manager) do
    local_root = File.join(File.dirname(__FILE__), 'resources', 'cloud')
    LocalManager.new(local_root:, type: TYPE_WASABI)
  end

  before(:each) do
    key = "#{depositor}/#{collection}/#{storage_manifest_filename}"
    wasabi_manager.upload_file(key, storage_manifest)
  end

  after do
    FileUtils.remove_dir(dir_to_clean)
    wasabi_manager.cleanup
  end

  context 'when initializing ingest env' do
    it 'creates ingest env' do
      env_initializer = Preingest::IngestEnvInitializer.new(
        ingest_root:, manifest_validator:, file_identifier:, wasabi_manager:)
      # env_initializer.initialize_ingest_env(data:, cmf: collection_manifest, imf: ingest_manifest,
      #                                       sfs_location:, ticket_id:,
      #                                       depositor:, collection_id: collection)

      env_initializer.initialize_ingest_env_from_params_obj(ingest_params:)
      got_path = File.join(ingest_root, depositor, collection)
      got_manifest_path = File.join(got_path, 'manifest')

      # compare ingest manifest
      source_imf = Manifests.read_manifest(filename: ingest_manifest)

      source_imf.walk_packages do |package|
        package.source_path = data
      end
      got_imf_path = File.join(got_manifest_path, 'ingest_manifest', File.basename(ingest_manifest))
      got_imf = Manifests.read_manifest(filename: got_imf_path)

      expected_imf = Manifests.read_manifest(filename: ingest_manifest)
      expected_imf.walk_packages do |package|
        package.source_path = data
        package.walk_files do |file|
          file.media_type = 'text/plain'
        end
      end

      got_imf.walk_packages do |package|
        expected_package = expected_imf.get_package(package_id: package.package_id)
        expect(package).to eq(expected_package)
      end
      expect(got_imf.number_packages).to eq(expected_imf.number_packages)

      # compare merged collection manifest
      expected_mm = Manifests.read_manifest(filename: merged_manifest)
      got_mm_path = File.join(got_manifest_path, 'collection_manifest', '_EM_test_depositor_test_collection.json')
      got_mm = Manifests.read_manifest(filename: got_mm_path)
      got_mm.walk_packages do |package|
        expected_package = expected_mm.get_package(package_id: package.package_id)
        expect(package).to eq(expected_package)
      end
      expect(got_mm.number_packages).to eq(expected_mm.number_packages)

      expected_yaml = YAML.load_file(expected_ingest_config)
      expected_yaml[:ingest_manifest] = File.join(got_manifest_path, 'ingest_manifest', expected_yaml[:ingest_manifest])
      got_yaml_path = File.join(got_path, 'config', 'ingest_config.yaml')
      got_yaml = YAML.load_file(got_yaml_path)
      expect(got_yaml[:type]).to eq(expected_yaml[:type])
      expect(got_yaml[:depositor]).to eq(expected_yaml[:depositor])
      expect(got_yaml[:collection]).to eq(expected_yaml[:collection])
      expect(got_yaml[:ingest_manifest]).to eq(expected_yaml[:ingest_manifest])
      expect(got_yaml[:ticket_id]).to eq(expected_yaml[:ticket_id])
    end
  end

  # context 'when initializing ingest env without collection manifest' do
  #   it 'creates ingest env without merged collection manifest' do
  #     env_initializer = Preingest::IngestEnvInitializer.new(ingest_root:, sfs_root:,
  #                                                           manifest_validator:,
  #                                                           file_identifier:)
  #     env_initializer.initialize_ingest_env(data:, cmf: 'none', imf: ingest_manifest,
  #                                           sfs_location:, ticket_id:,
  #                                           depositor:, collection_id: collection)
  #     collection_manifest = File.join(ingest_root, 'manifest', 'collection_manifest', '_EM_collection_manifest.json')
  #     expect(File.exist?(collection_manifest)).to be(false)
  #   end
  # end
end
