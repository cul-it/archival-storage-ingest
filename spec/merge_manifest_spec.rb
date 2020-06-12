# frozen_string_literal: true

require 'rspec'
require 'misc/merge_manifest'
require 'archival_storage_ingest/manifests/manifest_merger'
require 'archival_storage_ingest/workers/fixity_worker'

RSpec.describe 'MergeManifest' do # rubocop:disable Metrics/BlockLength
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

  before(:each) do
    @storage_manifest = Manifests::Manifest.new
    @ingest_manifest = Manifests::Manifest.new(json_text: ingest_manifest_hash.to_json)
  end

  context 'when storage manifest does not have a package in ingest manifest' do
    it 'adds the package to the storage manifest' do
      merge_manifest = Manifests::ManifestMerger.new
      merge_manifest.merge_manifests(storage_manifest: @storage_manifest, ingest_manifest: @ingest_manifest)
      expect(@storage_manifest.packages[0].to_json_fixity).to eq(@ingest_manifest.packages[0].to_json_fixity)
    end
  end

  context 'when storage manifest does not have a file entry in ingest manifest' do
    it 'addes the file to the package in storage manifest' do
      test_package = Manifests::Package.new(package: { package_id: FixityWorker::FIXITY_TEMPORARY_PACKAGE_ID })
      test_package.add_file_entry(filepath: '1/one.txt', sha1: 'ef72cf86c1599c80612317fdd2f50f4863c3efb0', size: 10)
      @storage_manifest.add_package(package: test_package)
      merge_manifest = Manifests::ManifestMerger.new
      merge_manifest.merge_manifests(storage_manifest: @storage_manifest, ingest_manifest: @ingest_manifest)
      expect(@storage_manifest.packages[0].to_json_fixity).to eq(@ingest_manifest.packages[0].to_json_fixity)
    end
  end
end

RSpec.describe 'MergeManifest' do # rubocop:disable Metrics/BlockLength
  let(:ingest_manifest) { File.join(File.dirname(__FILE__), 'resources', 'misc', 'ingest_manifest.json') }
  let(:collection_manifest) { File.join(File.dirname(__FILE__), 'resources', 'misc', 'collection_manifest.json') }
  let(:expected_json) do # rubocop:disable Metrics/BlockLength
    json_data = {
      'RMC/RMA/RMA03487_Cornell_University_Facilities_Construction_Records' => {
        'phys_coll_id' => 'RMA02471',
        'steward' => 'eef46',
        'number_files' => 5,
        'locations' => {
          's3' => [
            {
              'uri': 's3://s3-cular/RMC/RMA/RMA03487_Cornell_University_Facilities_Construction_Records'
            }
          ],
          'sfs' => [
            {
              'uri': 'smb://files.library.cornell.edu/lib/archival02/RMC/' \
                     'RMA/RMA03487_Cornell_University_Facilities_Construction_Records'
            }
          ]
        },
        'items' => {
          '1001_Barton Hall' => {
            'SUCF 161001 10069_2016_Flooring System Replacement' => {
              'AsBuilts_01_2017' => {
                'Images' => {
                  '285-408_G1-0_Gnrl Nts Abbrvtns and Symbls_A1.pdf' => {
                    'size' => 509_065,
                    'sha1' => '1df2314ccada2340777da47076c0d8ffa5da93ca'
                  },
                  'test.pdf' => {
                    'size' => 1_234,
                    'sha1' => 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef'
                  },
                  '285-410_G1-1_Code Assumptions Site Staging Pln_A3.pdf' => {
                    'size' => 395_412,
                    'sha1' => '686c21513f7d3eb537cabb71a90d96a380f60730'
                  },
                  '285-417_D2-1_Demolition Dtls Base Bid_A10.pdf' => {
                    'size' => 860_060,
                    'sha1' => '3c3fc1b215d3653fb8b98bb881196db089c0e309'
                  },
                  '285-418_D2-1A_Demolition Dtls Alter 1_A11.pdf' => {
                    'size' => 881_484,
                    'sha1' => '58bcbd5e888f35c1674c099ae49218b15f6def48'
                  }
                }
              }
            }
          }
        }
      }
    }
    JSON.pretty_generate(json_data)
  end

  context 'combining manifests with collision' do
    it 'replaces with entry in ingest manifest' do
      mm = MergeManifest::MergeManifest.new
      json_output = mm.merge_manifest(ingest_manifest, collection_manifest)
      expect(json_output).to eq(expected_json)
    end
  end
end
