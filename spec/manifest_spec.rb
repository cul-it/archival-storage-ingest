# frozen_string_literal: true

require 'rspec'
require 'spec_helper'
require 'archival_storage_ingest/workers/manifest'

RSpec.describe 'Manifest' do # rubocop:disable Metrics/BlockLength
  context 'when adding items' do
    it 'should add to items section and increment file count' do
      manifest = WorkerManifest::Manifest.new
      manifest.add_file('a/b/c/resource1.txt', 'deadbeef1')
      manifest.add_file('a/b/c/resource2.txt', 'deadbeef2')
      expected_hash = {
        'a/b/c/resource1.txt' => 'deadbeef1',
        'a/b/c/resource2.txt' => 'deadbeef2'
      }
      expected_number_files = 2
      expect(manifest.files).to eq(expected_hash)
      expect(manifest.number_files).to eq(expected_number_files)
    end
  end

  context 'when generating old manifest' do
    it 'should use semi-nested format' do
      manifest = WorkerManifest::Manifest.new
      manifest.add_file('a/b/c/resource1.txt', 'deadbeef1')
      manifest.add_file('a/b/c/resource2.txt', 'deadbeef2')
      expected_hash = {
        'a/b' => {
          items: {
            'c/resource1.txt' => {
              sha1: 'deadbeef1'
            },
            'c/resource2.txt' => {
              sha1: 'deadbeef2'
            }
          }
        }
      }
      expect(manifest.to_old_manifest('a', 'b')).to eq(expected_hash)
    end
  end
end

require 'rspec/expectations'
require 'archival_storage_ingest/manifests/manifests'

def resource(filename)
  File.join(File.dirname(__FILE__), ['resources', 'manifests', filename])
end

RSpec.describe 'Manifests' do # rubocop:disable Metrics/BlockLength
  context 'loading manifest' do
    let(:manifest10) { Manifests::Manifest.new(filename: resource('10ItemsFull.json')) }
    let(:manifest_arxiv) { Manifests::Manifest.new(filename: resource('arXiv.json')) }

    it 'can be loaded from files' do
      expect(manifest10.hash).to_not be_nil
    end

    it 'knows the depositor/collection' do
      expect(manifest10.depcol).to eq('MATH/LecturesEvents')
    end

    it 'has list of files' do
      expect(manifest10.files.keys).to including('MATH/LecturesEvents/MATH_2726859_V0098/MATH_2726859_V0098.mov')
    end

    it 'has shas from files' do
      expect(manifest10.files.values).to including('4a5d30968b132cd41644216cecb69da0a75d8c90')
    end

    it 'knows how many files' do
      manifest = Manifests::Manifest.new(filename: resource('10ItemsFull.json'))

      expect(manifest.size).to eq(10)
    end

    it 'knows how to deal with recursive directories' do
      expect(manifest_arxiv.size).to eq(8)

      first_file = manifest_arxiv.files.keys[0]
      expect(first_file).to eq('arXiv/arXiv/9107/2017-11-22/9107.zip')
      expect(manifest_arxiv.files[first_file]).to eq('bd03f1f4302bb7da67cb7bbac42c82a30feb9660')
    end
  end

  context 'comparing manifests' do
    let(:manifest10) { Manifests::Manifest.new(filename: resource('10ItemsFull.json')) }
    let(:manifest9) { Manifests::Manifest.new(filename: resource('9ItemsShaOnlyReordered.json')) }

    it 'a manifest is equal to itself' do
      diff = manifest10.diff(manifest10)

      expect(diff).to be_empty
    end

    it '10 items should differ from 9 items' do
      diff = manifest10.diff(manifest9)

      expect(diff).to have_key(manifest10.filename)
      expect(diff[manifest10.filename].size).to eq(1)

      expect(diff).to_not have_key(manifest9.filename)
    end

    it '9 items should differ from 10 items' do
      diff = manifest9.diff(manifest10)

      expect(diff).to have_key(manifest10.filename)
      expect(diff[manifest10.filename].size).to eq(1)

      expect(diff).to_not have_key(manifest9.filename)
    end
  end
end
