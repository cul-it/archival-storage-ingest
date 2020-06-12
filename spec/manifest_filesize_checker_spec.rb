# frozen_string_literal: true

require 'archival_storage_ingest/manifests/manifests'
require 'archival_storage_ingest/manifests/manifest_filesize_checker'
require 'rspec'

RSpec.describe 'IngestEnvInitializer' do # rubocop:disable Metrics/BlockLength
  let(:depositor) { 'test_depositor' }
  let(:collection) { 'test_collection' }
  let(:source_data) do
    File.join(File.dirname(__FILE__), 'resources', 'preingest', 'source_data')
  end
  let(:data) do
    File.join(source_data, depositor, collection)
  end
  let(:ingest_manifest) do
    manifest_file = File.join(source_data, '_EM_ingest_manifest.json')
    manifest = Manifests.read_manifest(filename: manifest_file)
    manifest.walk_packages do |package|
      package.source_path = data
    end
    manifest
  end

  context 'all file sizes match' do
    it 'reports no mismatch' do
      checker = Manifests::ManifestFilesizeChecker.new
      total, mismatch = checker.check_filesize(manifest: ingest_manifest)
      expect(total).to eq(56)
      expect(mismatch.empty?).to eq(true)
    end
  end

  context 'when file sizes do not match' do
    it 'reports mismatch' do
      ingest_manifest.packages[0].files[0].size = 11
      checker = Manifests::ManifestFilesizeChecker.new
      total, mismatch = checker.check_filesize(manifest: ingest_manifest)
      expect(total).to eq(56)
      expect(mismatch.size).to eq(1)
      expect(mismatch['3/three.txt'][:manifest]).to eq(11)
      expect(mismatch['3/three.txt'][:fs]).to eq(10)
    end
  end
end
