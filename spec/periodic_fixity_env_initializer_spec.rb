# frozen_string_literal: true

require 'archival_storage_ingest/manifests/manifests'
require 'archival_storage_ingest/preingest/periodic_fixity_env_initializer'
require 'archival_storage_ingest/workers/fixity_worker'

require 'fileutils'
require 'rspec'
require 'yaml'

RSpec.describe 'PeriodicFixityEnvInitializer' do # rubocop:disable BlockLength
  let(:depositor) { 'test_depositor' }
  let(:collection) { 'test_collection' }
  let(:periodic_fixity_root) do
    File.join(File.dirname(__FILE__), 'resources', 'preingest', 'periodic_fixity_root')
  end
  let(:sfs_root) do
    File.join(File.dirname(__FILE__), 'resources', 'preingest', 'sfs_root')
  end
  let(:source_data) do
    File.join(File.dirname(__FILE__), 'resources', 'preingest', 'source_data')
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
  let(:expected_periodic_fixity_config) do
    File.join(source_data, 'expected_ingest_config.yaml')
  end
  let(:data) do
    File.join(source_data, depositor, collection)
  end
  let(:sfs_location) { 'archival0x' }
  let(:ticket_id) { 'CULAR-xxxx' }
  let(:dir_to_clean) do
    File.join(periodic_fixity_root, depositor)
  end

  after(:each) do
    FileUtils.remove_dir(dir_to_clean)
  end

  context 'when initializing periodic fixity env' do # rubocop:disable BlockLength
    it 'creates periodic fixity env' do # rubocop:disable BlockLength
      env_initializer = Preingest::PeriodicFixityEnvInitializer.new(periodic_fixity_root: periodic_fixity_root, sfs_root: sfs_root)
      env_initializer.initialize_periodic_fixity_env(data: data, cmf: collection_manifest, imf: ingest_manifest,
                                                     sfs_location: sfs_location, ticket_id: ticket_id)
      got_path = File.join(periodic_fixity_root, depositor, collection)
      got_manifest_path = File.join(got_path, 'manifest')

      # compare ingest manifest
      source_imf = Manifests.read_manifest(filename: ingest_manifest)
      expected_source_path = File.join(periodic_fixity_root, depositor, collection, 'data', depositor, collection)
      source_imf.walk_packages do |package|
        package.source_path = expected_source_path
      end
      got_imf_path = File.join(got_manifest_path, 'ingest_manifest', File.basename(ingest_manifest))
      got_imf = Manifests.read_manifest(filename: got_imf_path)
      got_imf.walk_packages do |package|
        source_package = source_imf.get_package(package_id: package.package_id)
        expect(package).to eq(source_package)
      end
      expect(got_imf.number_packages).to eq(source_imf.number_packages)

      # compare merged collection manifest
      expected_mm = Manifests.read_manifest(filename: merged_manifest)
      got_mm_path = File.join(got_manifest_path, 'collection_manifest', File.basename(collection_manifest))
      got_mm = Manifests.read_manifest(filename: got_mm_path)
      got_mm.walk_packages do |package|
        expected_package = expected_mm.get_package(package_id: package.package_id)
        expect(package).to eq(expected_package)
      end
      expect(got_mm.number_packages).to eq(expected_mm.number_packages)

      expected_yaml = YAML.load_file(expected_periodic_fixity_config)
      expected_yaml[:dest_path] = File.join(sfs_root, expected_yaml[:dest_path])
      expected_yaml[:ingest_manifest] = File.join(got_manifest_path, 'ingest_manifest', expected_yaml[:ingest_manifest])
      got_yaml_path = File.join(got_path, 'config', 'periodic_fixity_config.yaml')
      got_yaml = YAML.load_file(got_yaml_path)
      expect(got_yaml[:depositor]).to eq(expected_yaml[:depositor])
      expect(got_yaml[:collection]).to eq(expected_yaml[:collection])
      expect(got_yaml[:dest_path]).to eq(expected_yaml[:dest_path])
      expect(got_yaml[:ingest_manifest]).to eq(expected_yaml[:ingest_manifest])
      expect(got_yaml[:ticket_id]).to eq(expected_yaml[:ticket_id])
    end
  end

  context 'when initializing periodic fixity env with multiple dest path' do
    it 'creates periodic fixity env with dest path joined by comma' do
      multiple_sfs_locations = "archival01#{FixityWorker::PeriodicFixitySFSGenerator::DEST_PATH_DELIMITER}archival02"
      env_initializer = Preingest::PeriodicFixityEnvInitializer.new(periodic_fixity_root: periodic_fixity_root, sfs_root: sfs_root)
      env_initializer.initialize_periodic_fixity_env(data: data, cmf: 'none', imf: ingest_manifest,
                                                     sfs_location: multiple_sfs_locations, ticket_id: ticket_id)
      got_path = File.join(periodic_fixity_root, depositor, collection)
      got_yaml_path = File.join(got_path, 'config', 'periodic_fixity_config.yaml')
      got_yaml = YAML.load_file(got_yaml_path)
      expected_dest_paths = []
      multiple_sfs_locations.split(',').each do |sfs_loc|
        expected_dest_paths << File.join(sfs_root, sfs_loc, depositor, collection).to_s
      end
      expected_dest_path = expected_dest_paths.join(FixityWorker::PeriodicFixitySFSGenerator::DEST_PATH_DELIMITER)
      expect(got_yaml[:dest_path]).to eq expected_dest_path
    end
  end
end
