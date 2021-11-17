# frozen_string_literal: true

require 'rspec'
require 'spec_helper'
require 'archival_storage_ingest/manifests/manifests'
require 'archival_storage_ingest/workers/fixity_worker'

RSpec.describe 'Manifest' do
  context 'when adding items' do
    it 'should add to items section and increment file count' do
      test_package_id = FixityWorker::FIXITY_TEMPORARY_PACKAGE_ID
      manifest = Manifests::Manifest.new(json_text: FixityWorker::FIXITY_MANIFEST_TEMPLATE_STR)
      manifest.add_filepath(package_id: test_package_id, filepath: 'a/b/c/resource1.txt', sha1: 'deadbeef1', size: 5)
      manifest.add_filepath(package_id: test_package_id, filepath: 'a/b/c/resource2.txt', sha1: 'deadbeef2', size: 10)
      expected_files = [
        Manifests::FileEntry.new(file: { filepath: 'a/b/c/resource1.txt', sha1: 'deadbeef1', size: 5 }),
        Manifests::FileEntry.new(file: { filepath: 'a/b/c/resource2.txt', sha1: 'deadbeef2', size: 10 })
      ]

      expected_number_files = 2
      expect(manifest.get_package(package_id: test_package_id).number_files).to eq(expected_number_files)

      files = []
      manifest.walk_filepath(package_id: test_package_id) do |file|
        files << file
      end
      expect(files[0]).to eq(expected_files[0])
      expect(files[1]).to eq(expected_files[1])
    end
  end

  # context 'when generating old manifest' do
  #   it 'should use semi-nested format' do
  #     manifest = WorkerManifest::Manifest.new
  #     manifest.add_file('a/b/c/resource1.txt', 'deadbeef1')
  #     manifest.add_file('a/b/c/resource2.txt', 'deadbeef2')
  #     expected_hash = {
  #       'a/b' => {
  #         items: {
  #           'c/resource1.txt' => {
  #             sha1: 'deadbeef1',
  #             size: 0
  #           },
  #           'c/resource2.txt' => {
  #             sha1: 'deadbeef2',
  #             size: 0
  #           }
  #         }
  #       }
  #     }
  #     expect(manifest.to_old_manifest('a', 'b')).to eq(expected_hash)
  #   end
  # end
end

require 'rspec/expectations'

def resource(filename)
  File.join(File.dirname(__FILE__), ['resources', 'manifests', filename])
end

RSpec.describe 'Manifests' do # rubocop:disable Metrics/BlockLength
  context 'loading manifest' do # rubocop:disable Metrics/BlockLength
    let(:manifest10) { Manifests.read_manifest(filename: resource('10ItemsFull.json')) }
    let(:manifest_arxiv) { Manifests.read_manifest(filename: resource('arXiv.json')) }

    it 'can be loaded from files' do
      expect(manifest10.hash).to_not be_nil
    end

    it 'knows the depositor/collection' do
      expect(manifest10.depositor).to eq('MATH')
      expect(manifest10.collection_id).to eq('LecturesEvents')
    end

    it 'has list of files' do
      expect(manifest10.flattened.keys).to include 'MATH_2726859_V0098/MATH_2726859_V0098.mov'
    end

    it 'has shas from files' do
      expect(manifest10.flattened.values.map(&:to_json_hash))
        .to include a_hash_including(sha1: '4a5d30968b132cd41644216cecb69da0a75d8c90')
    end

    it 'knows how many packages' do
      manifest = Manifests.read_manifest(filename: resource('10ItemsFull.json'))

      expect(manifest.number_packages).to eq(2)
    end

    it 'knows how to deal with recursive directories' do
      expect(manifest_arxiv.flattened.size).to eq(8)

      first_file = manifest_arxiv.flattened.keys[0]
      expect(first_file).to eq('9107/2017-11-22/9107.zip')
      expect(manifest_arxiv.flattened[first_file].sha1).to eq('bd03f1f4302bb7da67cb7bbac42c82a30feb9660')
    end
  end

  context 'comparing manifests' do
    let(:manifest10) { Manifests.read_manifest(filename: resource('10ItemsFull.json')) }
    let(:manifest9) { Manifests.read_manifest(filename: resource('9ItemsReordered.json')) }

    it 'a manifest is equal to itself' do
      diff = manifest10.diff(manifest10)

      expect(diff).to include(ingest: {})
      expect(diff).to include(other: {})
    end

    it '10 items should differ from 9 items' do
      diff = manifest10.diff(manifest9)

      expect(diff).to have_key(:ingest)
      expect(diff[:ingest].size).to eq(1)
    end

    it '9 items should differ from 10 items' do
      diff = manifest9.diff(manifest10)

      expect(diff).to have_key(:other)
      expect(diff[:other].size).to eq(1)
    end
  end
end

RSpec.describe 'Manifest Comparator' do # rubocop:disable Metrics/BlockLength
  let(:collection_manifest) do
    f = resource('comparator/collection_manifest.json')
    Manifests.read_manifest(filename: f)
  end
  let(:sfs_manifest) do
    f = resource('comparator/sfs.json')
    Manifests.read_manifest(filename: f)
  end
  let(:mismatch_manifest) do
    f = resource('comparator/sfs_mismatch.json')
    Manifests.read_manifest(filename: f)
  end

  context 'when comparing matching manifests' do
    it 'passes' do
      comparator = Manifests::ManifestComparator.new(cm_filename: '_EM_RMC_RMA_RMA02205_Cornell_football_films.json')
      status, _diff = comparator.fixity_diff(ingest: sfs_manifest, fixity: sfs_manifest)
      expect(status).to eq(true)
    end
  end

  context 'when comparing collection manifest to fixity manifest with normal fixity compare mode with ingest date' do
    it 'fails' do
      comparator = Manifests::ManifestComparator.new(cm_filename: '_EM_RMC_RMA_RMA02205_Cornell_football_films.json',
                                                     fixity_mode: false)
      status, _diff = comparator.fixity_diff(ingest: collection_manifest, fixity: sfs_manifest)
      expect(status).to eq(false)
    end
  end

  context 'when comparing collection manifest to fixity manifest in periodic fixity mode' do
    it 'ignores collection manifest entry from fixity manifest and passes' do
      comparator = Manifests::ManifestComparator.new(cm_filename: '_EM_RMC_RMA_RMA02205_Cornell_football_films.json')
      status, _diff = comparator.fixity_diff(ingest: collection_manifest, fixity: sfs_manifest)
      expect(status).to eq(true)
    end
  end

  context 'when manifests contain mismatch' do
    it 'returns false status and list of mismatch keys' do
      comparator = Manifests::ManifestComparator.new(cm_filename: '_EM_RMC_RMA_RMA02205_Cornell_football_films.json')
      status, diff = comparator.fixity_diff(ingest: sfs_manifest, fixity: mismatch_manifest)
      expect(status).to eq(false)
      expect(diff[:ingest]).to eq(%w[RMA02205_F0018/RMA02205_F0018.mov RMA02205_F0018/RMA02205_F0018.mp4])
      expect(diff[:other]).to eq(%w[RMA02205_F0018/NEW_RMA02205_F0018.mov RMA02205_F0018/RMA02205_F0018.mp4])
    end
  end
end
