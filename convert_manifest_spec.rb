# frozen_string_literal: true

require 'spec_helper'

require 'misc/convert_manifest'

RSpec.describe 'ConvertManifest' do # rubocop:disable Metrics/BlockLength
  after do
    # Do nothing
  end

  context 'when converting manifest' do # rubocop:disable Metrics/BlockLength
    before do
      manifest_json = ConvertManifest.convert_manifest(filename: resource('10ItemsFull.json'))
      @manifest = JSON.parse(manifest_json)
    end

    context 'it should have collection-level data' do # rubocop:disable Metrics/BlockLength
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
        expect(@manifest['documentation']).to eq('TBD')
      end

      it 'gets the locations' do
        expect(@manifest['locations']).to contain_exactly(
          's3://s3-cular/MATH/LecturesEvents',
          'smb://files.cornell.edu/lib/archival01/MATH/LecturesEvents'
        )
      end

      it 'gets the locations in new format' do
        manifest_json = ConvertManifest.convert_manifest(filename: resource('4ItemsFull.json'))
        manifest = JSON.parse(manifest_json)

        expect(manifest['locations']).to contain_exactly(
          's3://s3-cular/RMC/RMA/RMA00507_Dexter_Simpson_Kimball_papers',
          'smb://files.library.cornell.edu/lib/archival02/RMC/RMA/RMA00507_Dexter_Simpson_Kimball_papers'
        )
      end
    end

    context 'when looking at packages' do # rubocop:disable Metrics/BlockLength
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
    it 'should convert full nesting to the filepath' do
      manifest_json = ConvertManifest.convert_manifest(filename: resource('arXiv.json'))
      manifest = JSON.parse(manifest_json)
      filepath = manifest['packages'][0]['files'][0]['filepath']
      expect(filepath).to eq('9107/2017-11-22/9107.zip')
    end

    context 'with non-top-level packaging' do
      before do
        manifest_file = resource('nesteddeep.json')
        manifest_json = ConvertManifest.convert_manifest(filename: manifest_file, depth: 2)
        @manifest = JSON.parse(manifest_json)
      end
      it 'should get right number of packages' do
        expect(@manifest['number_packages']).to eq(4)
      end

      it 'should have full path in filepaths' do
        expect(@manifest['packages'][0]['files'][0]['filepath']).to eq('Simpsons/Season1/SimpsonsS1E1.mov')
      end
    end
  end
end

def resource(filename)
  File.join(File.dirname(__FILE__), ['resources', 'manifests', filename])
end
