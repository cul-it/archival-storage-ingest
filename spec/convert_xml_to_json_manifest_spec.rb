# frozen_string_literal: true

require 'rspec'
require 'archival_storage_ingest/manifests/convert_xml_to_json_manifest'

RSpec.describe 'ConvertXmlToJsonMetadata' do
  # rubocop:disable Metrics/LineLength
  let(:hashdeep_manifest_file) { File.join(File.dirname(__FILE__), 'resources', 'manifests', 'hashdeep_manifest.xml') }
  let(:collection_manifest_file) { File.join(File.dirname(__FILE__), 'resources', 'manifests', 'hashdeep_collection_manifest.json') }
  let(:ingest_manifest_file) { File.join(File.dirname(__FILE__), 'resources', 'manifests', 'hashdeep_ingest_manifest.json') }
  # rubocop:enable Metrics/LineLength
  let(:source_path) { 'bogus_source_path' }

  context 'When hashdeep generated xml is passed' do
    it 'converts to manifest' do
      cxtjm = Manifests::ConvertXmlToJsonManifest.new
      collection_manifest = Manifests.read_manifest(filename: collection_manifest_file)
      manifest_response = cxtjm.generate_ingest_manifest(xml: hashdeep_manifest_file,
                                                         manifest: collection_manifest, depth: 2,
                                                         source_path:)
      ingest_manifest = manifest_response.ingest_manifest
      overwrite_list = manifest_response.overwrite_list
      expected_ingest_manifest = Manifests.read_manifest(filename: ingest_manifest_file)
      expect(ingest_manifest.number_packages).to eq(3)
      expect(ingest_manifest.packages).to eq(expected_ingest_manifest.packages)
      expect(ingest_manifest.packages[0].package_id).to eq('urn:uuid:14ebd815-9b82-472d-85cd-b458bdd8bd62')
      expect(overwrite_list.size).to eq(1)
      # rubocop:disable Metrics/LineLength
      expected_overwrite_filepath = '1001_Barton Hall/10362_SUCF 161013_2016_ROTC Force Protection/Construction_11_2016/Specification/679_097_Specifications_11_2016.pdf'
      expect(overwrite_list[expected_overwrite_filepath][:collection_file_entry].sha1).to eq('deadbeef11111111deadbeef11111111deadbeef')
      expect(overwrite_list[expected_overwrite_filepath][:ingest_file_entry].sha1).to eq('deadbeef55555555deadbeef55555555deadbeef')
      # rubocop:enable Metrics/LineLength
      ingest_manifest.walk_packages do |package|
        expect(package.source_path).to eq(source_path)
      end
    end
  end
end
