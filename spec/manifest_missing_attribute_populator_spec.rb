# frozen_string_literal: true

require 'rspec'

require 'archival_storage_ingest/manifests/manifest_missing_attribute_populator'
require 'archival_storage_ingest/workers/fixity_worker'

RSpec.describe 'ManifestMissingAttributePopulator' do # rubocop:disable BlockLength
  let(:data_path) { File.join(File.dirname(__FILE__), 'resources', 'manifests', 'manifest_to_filesystem_comparator') }
  let(:depositor) { 'RMC/RMA' }
  let(:collection) { 'RMA01234' }
  let(:ingest_manifest_hash) do
    {
      collection_id: collection,
      depositor: depositor,
      number_packages: 1,
      packages: [
        {
          package_id: FixityWorker::FIXITY_TEMPORARY_PACKAGE_ID,
          files: [
            {
              filepath: '1/one.txt'
            },
            {
              filepath: '2/two.txt',
              sha1: '',
              size: 10
            }
          ]
        }
      ]
    }
  end
  let(:expected_ingest_manifest_hash) do
    {
      collection_id: collection,
      depositor: depositor,
      number_packages: 1,
      packages: [
        {
          package_id: FixityWorker::FIXITY_TEMPORARY_PACKAGE_ID,
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

  context 'manifest contains all attributes' do
    it 'does nothing' do
      manifest = Manifests::Manifest.new(json_text: expected_ingest_manifest_hash.to_json)
      populator = Manifests::ManifestMissingAttributePopulator.new
      populator.populate_missing_attribute(manifest: manifest, data_path: data_path)
      expect(manifest.get_package(package_id: FixityWorker::FIXITY_TEMPORARY_PACKAGE_ID).to_json_fixity.to_json)
        .to eq(expected_ingest_manifest_hash[:packages][0].to_json)
    end
  end

  context 'manifest is missing attributes' do
    it 'fills in missing attributes' do
      manifest = Manifests::Manifest.new(json_text: ingest_manifest_hash.to_json)
      populator = Manifests::ManifestMissingAttributePopulator.new
      converted_manifest = populator.populate_missing_attribute(manifest: manifest, data_path: data_path)
      expect(converted_manifest.get_package(package_id: FixityWorker::FIXITY_TEMPORARY_PACKAGE_ID).to_json_fixity.to_json)
        .to eq(expected_ingest_manifest_hash[:packages][0].to_json)
    end
  end
end
