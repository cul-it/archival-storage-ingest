# frozen_string_literal: true

# Deprecated
# require 'archival_storage_ingest/ingest_utils/ingest_params'
# require 'archival_storage_ingest/manifests/manifests'
# require 'archival_storage_ingest/messages/queues'
# require 'archival_storage_ingest/preingest/periodic_fixity_env_initializer'
# require 'archival_storage_ingest/workers/fixity_worker'

# require 'fileutils'
# require 'rspec'
# require 'yaml'

# RSpec.describe 'PeriodicFixityEnvInitializer' do
#   let(:depositor) { 'test_depositor' }
#   let(:collection) { 'test_collection' }
#   let(:periodic_fixity_root) do
#     File.join(File.dirname(__FILE__), 'resources', 'preingest', 'periodic_fixity')
#   end
#   let(:sfs_root) do
#     File.join(File.dirname(__FILE__), 'resources', 'preingest', 'sfs_root')
#   end
#   let(:source_data) do
#     File.join(File.dirname(__FILE__), 'resources', 'preingest', 'source_data')
#   end
#   let(:collection_manifest) do
#     File.join(source_data, '_EM_collection_manifest.json')
#   end
#   let(:merged_manifest) do
#     File.join(source_data, '_EM_merged_collection_manifest.json')
#   end
#   let(:expected_periodic_fixity_config) do
#     File.join(source_data, 'expected_periodic_fixity_config.yaml')
#   end
#   let(:data) do
#     File.join(source_data, depositor, collection)
#   end
#   let(:sfsbucket) { 'archival0x' }
#   let(:ticketid) { 'CULAR-xxxx' }
#   let(:dir_to_clean) do
#     File.join(periodic_fixity_root, depositor)
#   end
#   dev_queue_periodic_fixity = Queues.resolve_queue_name(
#     queue: Queues::QUEUE_PERIODIC_FIXITY, stage: ArchivalStorageIngest::STAGE_DEV
#   )

#   after do
#     FileUtils.remove_dir(dir_to_clean)
#   end

#   context 'when initializing periodic fixity env' do
#     it 'creates periodic fixity env' do
#       env_initializer = Preingest::PeriodicFixityEnvInitializer.new(
#         periodic_fixity_root:, sfs_root:
#       )
#       periodic_fixity_params = IngestUtils::PeriodicFixityParams.new(
#         storage_manifest: collection_manifest, sfsbucket:,
#         ticketid:, relay_queue_name: dev_queue_periodic_fixity
#       )
#       env_initializer.initialize_periodic_fixity_env_from_params_obj(periodic_fixity_params:)
#       got_path = File.join(periodic_fixity_root, depositor, collection)
#       got_manifest_path = File.join(got_path, 'manifest')

#       # compare ingest manifest
#       source_imf = Manifests.read_manifest(filename: collection_manifest)
#       got_imf_path = File.join(got_manifest_path, 'ingest_manifest', File.basename(collection_manifest))
#       got_imf = Manifests.read_manifest(filename: got_imf_path)
#       got_imf.walk_packages do |package|
#         source_package = source_imf.get_package(package_id: package.package_id)
#         expect(package).to eq(source_package)
#       end
#       expect(got_imf.number_packages).to eq(source_imf.number_packages)

#       expected_yaml = YAML.load_file(expected_periodic_fixity_config)
#       expected_yaml[:dest_path] = File.join(sfs_root, expected_yaml[:dest_path])
#       expected_yaml[:ingest_manifest] = File.join(got_manifest_path, 'ingest_manifest', expected_yaml[:ingest_manifest])
#       got_yaml_path = File.join(got_path, 'config', 'periodic_fixity_config.yaml')
#       got_yaml = YAML.load_file(got_yaml_path)
#       expect(got_yaml[:type]).to eq(expected_yaml[:type])
#       expect(got_yaml[:depositor]).to eq(expected_yaml[:depositor])
#       expect(got_yaml[:collection]).to eq(expected_yaml[:collection])
#       expect(got_yaml[:dest_path]).to eq(expected_yaml[:dest_path])
#       expect(got_yaml[:ingest_manifest]).to eq(expected_yaml[:ingest_manifest])
#       expect(got_yaml[:ticket_id]).to eq(expected_yaml[:ticket_id])
#     end
#   end

#   context 'when initializing periodic fixity env with multiple dest path' do
#     it 'creates periodic fixity env with dest path joined by comma' do
#       multiple_sfs_locations = "archival01#{FixityWorker::PeriodicFixitySFSGenerator::DEST_PATH_DELIMITER}archival02"
#       env_initializer = Preingest::PeriodicFixityEnvInitializer.new(
#         periodic_fixity_root:, sfs_root:
#       )
#       periodic_fixity_params = IngestUtils::PeriodicFixityParams.new(
#         storage_manifest: collection_manifest, sfsbucket: multiple_sfs_locations,
#         ticketid:, relay_queue_name: dev_queue_periodic_fixity
#       )
#       env_initializer.initialize_periodic_fixity_env_from_params_obj(periodic_fixity_params:)
#       got_path = File.join(periodic_fixity_root, depositor, collection)
#       got_yaml_path = File.join(got_path, 'config', 'periodic_fixity_config.yaml')
#       got_yaml = YAML.load_file(got_yaml_path)
#       expected_dest_paths = []
#       multiple_sfs_locations.split(',').each do |sfs_loc|
#         expected_dest_paths << File.join(sfs_root, sfs_loc, depositor, collection).to_s
#       end
#       expected_dest_path = expected_dest_paths.join(FixityWorker::PeriodicFixitySFSGenerator::DEST_PATH_DELIMITER)
#       expect(got_yaml[:dest_path]).to eq expected_dest_path
#     end
#   end

#   context 'when given relay_queue_name' do
#     it 'adds queue_name to the output config' do
#       env_initializer = Preingest::PeriodicFixityEnvInitializer.new(
#         periodic_fixity_root:, sfs_root:
#       )
#       periodic_fixity_params = IngestUtils::PeriodicFixityParams.new(
#         storage_manifest: collection_manifest, sfsbucket:,
#         ticketid:, relay_queue_name: dev_queue_periodic_fixity
#       )
#       env_initializer.initialize_periodic_fixity_env_from_params_obj(periodic_fixity_params:)
#       got_path = File.join(periodic_fixity_root, depositor, collection)
#       got_yaml_path = File.join(got_path, 'config', 'periodic_fixity_config.yaml')
#       got_yaml = YAML.load_file(got_yaml_path)
#       expect(got_yaml[:queue_name]).to eq(dev_queue_periodic_fixity)
#     end
#   end
# end
