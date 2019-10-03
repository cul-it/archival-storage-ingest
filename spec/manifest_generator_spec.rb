# frozen_string_literal: true

require 'rspec'
require 'archival_storage_ingest/manifests/manifest_generator'

manifest_hash = {
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

depositor = 'RMC/RMA'
collection_id = 'RMA01234'
data_path = File.join(File.dirname(__FILE__), 'resources',
                      'manifests', 'manifest_to_filesystem_comparator', 'RMC', 'RMA', 'RMA01234')
ingest_manifest = File.join(File.dirname(__FILE__), 'resources', 'manifests', 'manifest_generator', 'ingest_manifest.json')

RSpec.describe 'ManifestGeneratorS3' do # rubocop:disable BlockLength
  let(:s3_manager) do
    s3m = S3Manager.new('bogus_bucket')

    allow(s3m).to receive(:upload_string)
      .with(any_args)
      .and_raise(IngestException, 'upload_string must not be called in this test!')

    allow(s3m).to receive(:upload_file)
      .with(any_args)
      .and_raise(IngestException, 'upload_file must not be called in this test!')

    allow(s3m).to receive(:list_object_keys)
      .with("#{depositor}/#{collection_id}") do
      %W[
        #{depositor}/#{collection_id}/1/one.txt
        #{depositor}/#{collection_id}/2/two.txt
      ]
    end

    allow(s3m).to receive(:calculate_checksum)
      .with("#{depositor}/#{collection_id}/1/one.txt") { ['ef72cf86c1599c80612317fdd2f50f4863c3efb0', 10] }

    allow(s3m).to receive(:calculate_checksum)
      .with("#{depositor}/#{collection_id}/2/two.txt") { ['158481d59505dedf144ec5e4b87e92043f48ab68', 10] }

    allow(s3m).to receive(:retrieve_file)
      .with(any_args)
      .and_raise(IngestException, 'retrieve_file must not be called in this test!')

    s3m
  end

  context 'when generating s3 manifest' do
    it 'creates fixity manifest based on the s3 listing' do
      s3_manifest_generator = Manifests::ManifestGeneratorS3.new(
        depositor: depositor, collection_id: collection_id, s3_manager: s3_manager
      )
      manifest = s3_manifest_generator.generate_manifest
      expect(manifest.packages[0].to_json_fixity).to eq(manifest_hash[:packages][0])
      expect(manifest.packages[0].number_files).to eq(2)
      expect(manifest.packages[0].files[0].filepath).to eq(manifest_hash[:packages][0][:files][0][:filepath])
    end
  end

  context 'when generating update s3 manifest' do
    it 'only checks items in ingest manifest' do
      s3_manifest_generator = Manifests::ManifestGeneratorS3.new(
        depositor: depositor, collection_id: collection_id, s3_manager: s3_manager,
        ingest_manifest: ingest_manifest
      )
      manifest = s3_manifest_generator.generate_manifest
      expect(manifest.packages[0].number_files).to eq(1)
      expect(manifest.packages[0].files[0].filepath).to eq(manifest_hash[:packages][0][:files][0][:filepath])
    end
  end
end

RSpec.describe 'ManifestGeneratorSFS' do
  context 'when generating sfs manifest' do
    it 'creates fixity manifest based on the filesystem' do
      sfs_manifest_generator = Manifests::ManifestGeneratorSFS.new(
        depositor: depositor, collection_id: collection_id, data_path: data_path
      )
      manifest = sfs_manifest_generator.generate_manifest
      expect(manifest.packages[0].to_json_fixity).to eq(manifest_hash[:packages][0])
      expect(manifest.packages[0].number_files).to eq(2)
      expect(manifest.packages[0].files[0].filepath).to eq(manifest_hash[:packages][0][:files][0][:filepath])
    end
  end

  context 'when generating update sfs manifest' do
    it 'only checks items in ingest manifest' do
      sfs_manifest_generator = Manifests::ManifestGeneratorSFS.new(
        depositor: depositor, collection_id: collection_id, data_path: data_path,
        ingest_manifest: ingest_manifest
      )
      manifest = sfs_manifest_generator.generate_manifest
      expect(manifest.packages[0].number_files).to eq(1)
      expect(manifest.packages[0].files[0].filepath).to eq(manifest_hash[:packages][0][:files][0][:filepath])
    end
  end
end
