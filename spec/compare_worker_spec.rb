# frozen_string_literal:true

require 'spec_helper'
require 'rspec/mocks'
require 'aws-sdk-s3'

def resource(filename)
  File.join(File.dirname(__FILE__), ['resources', 'manifests', filename])
end

RSpec.describe 'FixityCheckWorker' do # rubocop: disable Metrics/BlockLength
  subject(:worker) { FixityCompareWorker::ManifestComparator.new(s3_manager) }

  let(:s3_manager) { spy('s_manager') }

  let(:manifest10) { File.open(resource('10ItemsShaOnly.json')) }
  let(:manifest10b) { File.open(resource('10ItemsFull.json')) }

  let(:msg) do
    IngestMessage::SQSMessage.new(
      ingest_id: 'test_1234',
      data_path: ''
    )
  end

  context 'when called with incomplete diffs completed' do
    it 'no s3 diff makes it exit successfully' do
      allow(s3_manager).to receive(:retrieve_file).and_raise(Aws::S3::Errors::NoSuchKey.new('context', 'no S3 manifest'))

      result = worker.work(msg)

      expect(result).to be_truthy
      expect(s3_manager).to have_received(:retrieve_file).with('.manifests/test_1234_S3.json')
      expect(s3_manager).to_not have_received(:retrieve_file).with('.manifests/test_1234_SFS.json')
    end
    it 'no sfs diff makes it exit successfully' do
      allow(s3_manager).to receive(:retrieve_file)
        .with('.manifests/test_1234_S3.json')
        .and_return(true)
      allow(s3_manager).to receive(:retrieve_file)
        .with('.manifests/test_1234_SFS.json')
        .and_raise(Aws::S3::Errors::NoSuchKey.new('context', 'no SFS manifest'))

      result = worker.work(msg)

      expect(result).to be_truthy
      expect(s3_manager).to have_received(:retrieve_file).with('.manifests/test_1234_S3.json')
      expect(s3_manager).to have_received(:retrieve_file).with('.manifests/test_1234_SFS.json')
    end
  end
end
