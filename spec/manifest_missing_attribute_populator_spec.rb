# frozen_string_literal: true

require 'rspec'

require 'archival_storage_ingest/manifests/manifest_missing_attribute_populator'
require 'archival_storage_ingest/workers/fixity_worker'

RSpec.describe 'ManifestMissingAttributePopulator' do
  let(:source_path) do
    File.join(File.dirname(__FILE__), 'resources', 'manifests', 'manifest_to_filesystem_comparator', 'RMC', 'RMA',
              'RMA01234')
  end
  let(:depositor) { 'RMC/RMA' }
  let(:collection) { 'RMA01234' }
  let(:ingest_manifest_hash) do
    {
      collection_id: collection,
      depositor:,
      number_packages: 2,
      packages: [
        {
          package_id: FixityWorker::FIXITY_TEMPORARY_PACKAGE_ID,
          source_path:,
          files: [
            { filepath: '1/one.txt' },
            {
              filepath: '2/two.txt',
              sha1: '',
              size: 10
            }
          ]
        },
        {
          package_id: 'bogus_package_id',
          number_files: 1,
          files: [
            {
              filepath: '1/one.txt',
              sha1: 'ef72cf86c1599c80612317fdd2f50f4863c3efb0',
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
      depositor:,
      number_packages: 1,
      packages: [
        {
          package_id: FixityWorker::FIXITY_TEMPORARY_PACKAGE_ID,
          source_path:,
          number_files: 2,
          files: [
            {
              filepath: '1/one.txt',
              sha1: 'ef72cf86c1599c80612317fdd2f50f4863c3efb0',
              size: 10,
              tool_version: 'Apache Tika 2.1.0',
              media_type: 'text/plain'
            },
            {
              filepath: '2/two.txt',
              sha1: '158481d59505dedf144ec5e4b87e92043f48ab68',
              size: 10,
              tool_version: 'Apache Tika 2.1.0',
              media_type: 'text/plain'
            }
          ]
        },
        {
          package_id: 'bogus_package_id',
          source_path:,
          number_files: 1,
          files: [
            {
              filepath: '1/one.txt',
              sha1: 'ef72cf86c1599c80612317fdd2f50f4863c3efb0',
              size: 10,
              tool_version: 'Apache Tika 2.1.0',
              media_type: 'text/plain'
            }
          ]
        }
      ]
    }
  end
  let(:file_identifier) do
    fi = Manifests::FileIdentifier.new(sfs_prefix: 'bogus')
    allow(fi).to receive(:identify_from_source).with(any_args).and_return('text/plain')
    allow(fi).to receive(:identify_from_storage).with(any_args).and_return('text/plain')
    fi
  end

  context 'manifest contains all attributes' do
    it 'does nothing' do
      manifest = Manifests::Manifest.new(json_text: expected_ingest_manifest_hash.to_json)
      manifest.walk_packages do |package|
        package.source_path = source_path
      end
      populator = Manifests::ManifestMissingAttributePopulator.new(file_identifier:)
      populator.populate_missing_attribute(manifest:)
      expect(manifest.get_package(package_id: FixityWorker::FIXITY_TEMPORARY_PACKAGE_ID).to_json_ingest)
        .to eq(expected_ingest_manifest_hash[:packages][0])
    end
  end

  context 'manifest is missing attributes' do
    it 'fills in missing attributes' do
      manifest = Manifests::Manifest.new(json_text: ingest_manifest_hash.to_json)
      manifest.walk_packages do |package|
        package.source_path = source_path
      end
      populator = Manifests::ManifestMissingAttributePopulator.new(file_identifier:)
      converted_manifest = populator.populate_missing_attribute(manifest:)
      expect(converted_manifest.get_package(package_id: FixityWorker::FIXITY_TEMPORARY_PACKAGE_ID).to_json_ingest)
        .to eq(expected_ingest_manifest_hash[:packages][0])
      expect(manifest.packages[1].source_path).to eq(source_path)
    end
  end
end
