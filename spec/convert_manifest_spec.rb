# frozen_string_literal: true

require 'spec_helper'

require 'misc/convert_manifest'

RSpec.describe 'ConvertManifest' do # rubocop:disable Metrics/BlockLength
  before do
    manifest_json = ConvertManifest.convert_manifest(filename: resource('10ItemsFull.json'))
    @manifest = JSON.parse(manifest_json)
  end

  after do
    # Do nothing
  end

  context 'when converting manifest' do
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

      it 'gets the rights' do
        expect(@manifest['rights']).to eq('TBD')
      end

      it 'gets the locations' do
        expect(@manifest['locations']).to include('s3://s3-cular/MATH/LecturesEvents')
        expect(@manifest['locations']).to include('smb://files.cornell.edu/lib/archival01/MATH/LecturesEvents')
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
          @file = @files[0]
        end

        it 'files have a filepath' do
          expect(@file['filepath']).to eq('MATH_2726859_V0098/MATH_2726859_V0098.mov')
        end

        it 'files have a sha1' do
          expect(@file['sha1']).to match(/^\h{40}$/)
        end

        it 'files have a size' do
          expect(@file['size']).to eq(46215762895)
        end

        it 'files do not have a bibid' do
          expect(@file['bibid']).to be_nil
        end
      end

    end
  end
end

def resource(filename)
  File.join(File.dirname(__FILE__), ['resources', 'manifests', filename])
end
