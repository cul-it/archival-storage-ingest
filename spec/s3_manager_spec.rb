# frozen_string_literal: true

require 'rspec'
require 'spec_helper'

RSpec.describe 'S3 Manager' do
  context 'when generating manifest key' do
    it 'returns s3 key' do
      s3_bucket = 'bogus_bucket'
      s3_manager = S3Manager.new(s3_bucket)
      manifest_s3_key = s3_manager.manifest_key('1234', 'sfs')
      expect(manifest_s3_key).to eq('.manifest/1234_sfs.json')
    end
  end
end
