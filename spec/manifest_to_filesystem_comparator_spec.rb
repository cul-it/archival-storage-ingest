# frozen_string_literal: true

require 'rspec'

require 'archival_storage_ingest/manifests/manifests'
require 'archival_storage_ingest/manifests/manifest_to_filesystem_comparator'
require 'archival_storage_ingest/workers/fixity_worker'

RSpec.describe 'ManifestToFilesystemComparator' do # rubocop:disable Metrics/BlockLength
  let(:source_path) do
    File.join(File.dirname(__FILE__), 'resources', 'manifests', 'manifest_to_filesystem_comparator', 'RMC', 'RMA', 'RMA01234')
  end
  let(:depositor) { 'RMC/RMA' }
  let(:collection_id) { 'RMA01234' }
  let(:ingest_manifest_hash) do
    {
      collection_id: collection_id,
      depositor: depositor,
      number_packages: 1,
      packages: [
        {
          package_id: FixityWorker::FIXITY_TEMPORARY_PACKAGE_ID,
          number_files: 2,
          files: [
            {
              filepath: '1/one.txt',
              sha1: 'ef72cf86c1599c80612317fdd2f50f4863c3efb0',
              size: 10
            },
            {
              filepath: '2/two.txt',
              sha1: '158481d59505dedf144ec5e4b87e92043f48ab68',
              size: 10
            }
          ]
        }
      ]
    }
  end

  context 'manifest and filesystem listings match' do
    it 'succeeds' do
      manifest = Manifests::Manifest.new(json_text: ingest_manifest_hash.to_json)
      comparator = Manifests::ManifestToFilesystemComparator.new
      status = comparator.compare_manifest_to_filesystem(manifest: manifest, source_path: source_path)
      expect(status).to eq(true)
    end
  end

  context 'manifest does not have file in filesystem' do
    it 'fails' do
      manifest = Manifests::Manifest.new(json_text: ingest_manifest_hash.to_json)
      manifest.get_package(package_id: FixityWorker::FIXITY_TEMPORARY_PACKAGE_ID).files.pop
      comparator = Manifests::ManifestToFilesystemComparator.new
      status = comparator.compare_manifest_to_filesystem(manifest: manifest, source_path: source_path)
      expect(status).to eq(false)
    end
  end

  context 'filesystem does not have file in manifest' do
    it 'fails' do
      manifest = Manifests::Manifest.new(json_text: ingest_manifest_hash.to_json)
      manifest.add_filepath(package_id: FixityWorker::FIXITY_TEMPORARY_PACKAGE_ID, filepath: 'bogus', sha1: 'deadbeef', size: 1)
      comparator = Manifests::ManifestToFilesystemComparator.new
      status = comparator.compare_manifest_to_filesystem(manifest: manifest, source_path: source_path)
      expect(status).to eq(false)
    end
  end
end
