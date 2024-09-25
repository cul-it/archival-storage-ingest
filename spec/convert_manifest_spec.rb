# frozen_string_literal: true

require 'spec_helper'
require 'misc/convert_manifest'
require 'json'

RSpec.describe 'ConvertManifest' do
  let(:convert_manifest) do
    pid_file = resource('pid_list.txt')
    ConvertManifest::ConvertManifest.new(pid_file:)
  end

  context 'when converting manifest' do
    before do
      manifest_json = JSON.pretty_generate(
        convert_manifest.convert_manifest_to_new_hash(filename: resource('10ItemsOldManifest.json'), depth: 1)
      )
      @manifest = JSON.parse(manifest_json)
    end

    context 'it should have collection-level data' do
      it 'gets the steward' do
        expect(@manifest['steward']).to eq('swr1')
      end

      it 'gets the depositor' do
        expect(@manifest['depositor']).to eq('MATH')
      end

      it 'gets the collection id' do
        expect(@manifest['collection_id']).to eq('LecturesEvents')
      end

      it 'gets the documentation' do
        expect(@manifest['documentation']).to eq('cular:1')
      end
    end

    context 'when looking at packages' do
      before do
        @packages = @manifest['packages']
        @package = @packages[0]
      end

      it 'there are two of them (for this test file)' do
        expect(@packages.length).to be(2)
      end

      it 'they have a package id' do
        expect(@package['package_id']).to match(/^urn:uuid:\h{8}-\h{4}-\h{4}-\h{4}-\h{12}$/)
      end

      it 'they have non-empty files' do
        expect(@package['files']).not_to be_empty
      end

      it 'they have bibids' do
        expect(@package['bibid']).to eq('2726859')
      end

      it 'they have file counts' do
        expect(@package['number_files']).to be(4)
        expect(@package['files'].length).to be(4)
      end

      context 'when looking at files in packages' do
        before do
          @files = @package['files']
          @asset = @files[0]
        end

        it 'files have a filepath' do
          expect(@asset['filepath']).to eq('MATH_2726859_V0098/MATH_2726859_V0098.mov')
        end

        it 'files have a sha1' do
          expect(@asset['sha1']).to match(/^\h{40}$/)
        end

        it 'files have a size' do
          expect(@asset['size']).to eq(46_215_762_895)
        end

        it 'files do not have a bibid' do
          expect(@asset['bibid']).to be_nil
        end
      end
    end
  end

  context 'when converting a manifest with nested paths' do
    it 'converts full nesting to the filepath' do
      manifest_json = JSON.pretty_generate(
        convert_manifest.convert_manifest_to_new_hash(
          filename: resource('arXivOldManifest.json'), depth: 1
        )
      )
      manifest = JSON.parse(manifest_json)
      filepath = manifest['packages'][0]['files'][0]['filepath']
      expect(filepath).to eq('9107/2017-11-22/9107.zip')
    end

    context 'with non-top-level packaging' do
      before do
        manifest_file = resource('nesteddeep.json')
        manifest_json = JSON.pretty_generate(
          convert_manifest.convert_manifest_to_new_hash(filename: manifest_file, depth: 2)
        )
        @manifest = JSON.parse(manifest_json)
      end

      it 'gets right number of packages' do
        expect(@manifest['number_packages']).to eq(4)
      end

      it 'has full path in filepaths' do
        expect(@manifest['packages'][0]['files'][0]['filepath']).to eq('Simpsons/Season1/SimpsonsS1E1.mov')
      end
    end
  end

  context 'when reading csv metadata' do
    it 'returns hash keyed off of filepath' do
      csv_file = resource('metadata.csv')
      csv_metadata = convert_manifest.populate_csv(filename: csv_file, key: 'filepath')
      expect(csv_metadata.size).to eq(4)
    end
  end
end

def resource(filename)
  File.join(File.dirname(__FILE__), ['resources', 'manifests', filename])
end
