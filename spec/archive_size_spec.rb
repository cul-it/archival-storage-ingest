# frozen_string_literal: true

require 'rspec'
require 'misc/archive_size'
require 'json'

RSpec.describe ArchiveSize do
  let(:archive_size_json) { File.join(File.dirname(__FILE__), 'resources', 'misc', 'cular_archive_space.json') }
  let(:archive_size_file) { File.read(archive_size_json) }
  let(:archive_size_data) { JSON.parse(archive_size_file) }
  let(:s3_manager) do
    s3m = S3Manager.new('bogus_bucket')

    allow(s3m).to receive(:upload_file)
      .with(any_args)
      .and_raise(IngestException, 'upload_file must not be called in this test!')

    allow(s3m).to receive(:upload_asif_manifest)
      .with(any_args)
      .and_raise(IngestException, 'upload_asif_manifest must not be called in this test!')

    allow(s3m).to receive(:upload_asif_archive_size)
      .with(s3_key: 'cular_archive_space.json', data: archive_size_data).and_return(true)

    allow(s3m).to receive(:upload_string)
      .with(any_args)
      .and_raise(IngestException, 'upload_string must not be called in this test!')

    allow(s3m).to receive(:list_object_keys)
      .with(any_args)
      .and_raise(IngestException, 'list_object_keys must not be called in this test!')

    allow(s3m).to receive(:calculate_checksum)
      .with(any_args)
      .and_raise(IngestException, 'calculate_checksum must not be called in this test!')

    allow(s3m).to receive(:manifest_key)
      .with(any_args)
      .and_raise(IngestException, 'manifest_key must not be called in this test!')

    allow(s3m).to receive(:retrieve_file)
      .with(any_args)
      .and_raise(IngestException, 'retrieve_file must not be called in this test!')

    allow(s3m).to receive(:download_file)
      .with(any_args)
      .and_raise(IngestException, 'download_file must not be called in this test!')

    allow(s3m).to receive(:delete_object)
      .with(any_args)
      .and_raise(IngestException, 'delete_object must not be called in this test!')

    s3m
  end

  it 'deploys archive size json to s3' do
    archives = [
      { path: '/cul/data/archival01' },
      { path: '/cul/data/archival02' },
      { path: '/cul/data/archival03' },
      { path: '/cul/data/archival04' },
      { path: '/cul/data/archival05' }
    ]

    @archive_size = ArchiveSize::ArchiveSize.new(archives:, s3_manager:)
    @archive_size.deploy_asif_archive_size(archive_size_data)
    expect(s3_manager).to have_received(:upload_asif_archive_size).exactly(1).times
  end
end
