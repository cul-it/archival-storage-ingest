# frozen_string_literal: true

require 'rspec'
require 'spec_helper'

RSpec.describe 'Manifest' do
  context 'when adding items' do
    it 'should add to items section and increment file count' do
      manifest = Manifest.new
      manifest.add_file('/a/b/c/resource1.txt', 'deadbeef1')
      manifest.add_file('/a/b/c/resource2.txt', 'deadbeef2')
      expected_hash = {
        number_files: 2,
        files: [
          {
            filepath: '/a/b/c/resource1.txt',
            sha1: 'deadbeef1'
          },
          {
            filepath: '/a/b/c/resource2.txt',
            sha1: 'deadbeef2'
          }
        ]
      }
      expect(manifest.manifest_hash).to eq(expected_hash)
    end
  end
end
