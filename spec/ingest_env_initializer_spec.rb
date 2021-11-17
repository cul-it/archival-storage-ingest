# frozen_string_literal: true

require 'archival_storage_ingest/manifests/manifests'
require 'archival_storage_ingest/preingest/ingest_env_initializer'

require 'fileutils'
require 'json_schemer'
require 'rspec'
require 'yaml'

RSpec.describe 'IngestEnvInitializer' do # rubocop:disable Metrics/BlockLength
  let(:depositor) { 'test_depositor' }
  let(:collection) { 'test_collection' }
  let(:base_dir) { File.dirname(__FILE__) }
  let(:ingest_root) do
    File.join(base_dir, 'resources', 'preingest', 'ingest_root')
  end
  let(:sfs_root) do
    File.join(base_dir, 'resources', 'preingest', 'sfs_root')
  end
  let(:source_data) do
    File.join(base_dir, 'resources', 'preingest', 'source_data')
  end
  let(:collection_manifest) do
    File.join(source_data, '_EM_collection_manifest.json')
  end
  let(:ingest_manifest) do
    File.join(source_data, '_EM_ingest_manifest.json')
  end
  let(:merged_manifest) do
    File.join(source_data, '_EM_merged_collection_manifest.json')
  end
  let(:expected_ingest_config) do
    File.join(source_data, 'expected_ingest_config.yaml')
  end
  let(:data) do
    File.join(source_data, depositor, collection)
  end
  let(:sfs_location) { 'archival0x' }
  let(:ticket_id) { 'CULAR-xxxx' }
  let(:dir_to_clean) do
    File.join(ingest_root, depositor)
  end
  let(:storage_schema) do
    File.join(base_dir, 'resources', 'schema', 'manifest_schema_storage.json')
  end
  let(:ingest_schema) do
    File.join(base_dir, 'resources', 'schema', 'manifest_schema_ingest.json')
  end
  let(:manifest_validator) do
    Manifests::ManifestValidator.new(ingest_schema: ingest_schema,
                                     storage_schema: storage_schema)
  end
  let(:file_identifier) do
    fi = Manifests::FileIdentifier.new(sfs_prefix: 'bogus')
    allow(fi).to receive(:identify_from_source).with(any_args) { 'text/plain' }
    allow(fi).to receive(:identify_from_storage).with(any_args) { 'text/plain' }
    fi
  end

  after(:each) do
    FileUtils.remove_dir(dir_to_clean)
  end

  context 'when initializing ingest env' do # rubocop:disable Metrics/BlockLength
    it 'creates ingest env' do # rubocop:disable Metrics/BlockLength
      env_initializer = Preingest::IngestEnvInitializer.new(ingest_root: ingest_root, sfs_root: sfs_root,
                                                            manifest_validator: manifest_validator,
                                                            file_identifier: file_identifier)
      env_initializer.initialize_ingest_env(data: data, cmf: collection_manifest, imf: ingest_manifest,
                                            sfs_location: sfs_location, ticket_id: ticket_id,
                                            depositor: depositor, collection_id: collection)
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
      expected_yaml[:dest_path] = File.join(sfs_root, expected_yaml[:dest_path])
      expected_yaml[:ingest_manifest] = File.join(got_manifest_path, 'ingest_manifest', expected_yaml[:ingest_manifest])
      got_yaml_path = File.join(got_path, 'config', 'ingest_config.yaml')
      got_yaml = YAML.load_file(got_yaml_path)
      expect(got_yaml[:type]).to eq(expected_yaml[:type])
      expect(got_yaml[:depositor]).to eq(expected_yaml[:depositor])
      expect(got_yaml[:collection]).to eq(expected_yaml[:collection])
      expect(got_yaml[:dest_path]).to eq(expected_yaml[:dest_path])
      expect(got_yaml[:ingest_manifest]).to eq(expected_yaml[:ingest_manifest])
      expect(got_yaml[:ticket_id]).to eq(expected_yaml[:ticket_id])
    end
  end

  context 'when initializing ingest env without collection manifest' do
    it 'creates ingest env without merged collection manifest' do
      env_initializer = Preingest::IngestEnvInitializer.new(ingest_root: ingest_root, sfs_root: sfs_root,
                                                            manifest_validator: manifest_validator,
                                                            file_identifier: file_identifier)
      env_initializer.initialize_ingest_env(data: data, cmf: 'none', imf: ingest_manifest,
                                            sfs_location: sfs_location, ticket_id: ticket_id,
                                            depositor: depositor, collection_id: collection)
      collection_manifest = File.join(ingest_root, 'manifest', 'collection_manifest', '_EM_collection_manifest.json')
      expect(File.exist?(collection_manifest)).to eq(false)
    end
  end
end
