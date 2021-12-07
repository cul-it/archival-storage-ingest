# frozen_string_literal: true

require 'archival_storage_ingest/manifests/manifests'
require 'archival_storage_ingest/messages/ingest_message'
require 'archival_storage_ingest/workers/m2m_initiate_worker'

require 'fileutils'
require 'rspec'
require 'yaml'
require 'zip'

depositor = 'eCommons'
collection = 'eCommons'
resource_path = File.join(File.dirname(__FILE__), 'resources', 'm2m')
zip_filename = 'handle-1234.zip'
test_zip = File.join(resource_path, zip_filename)
package_zip_dir = File.join(resource_path, 'package_zip_dir')
package_extract_dir = File.join(resource_path, 'package_extract_dir')
package_extracted_dir = File.join(package_extract_dir, depositor, collection)
temp_dir = File.join(resource_path, 'temp')
temp_extracted_dir = File.join(temp_dir, 'handle-1234')
ingest_root = File.join(resource_path, 'ingest_root')
sfs_root = File.join(resource_path, 'sfs_root')
params = {
  type: IngestMessage::TYPE_M2M,
  ingest_id: 'TEST1234', original_msg: nil, dest_path: '',
  depositor: depositor, collection: collection, ingest_manifest: '',
  ticket_id: 'BOGUS-1234',
  package: 'handle-1234.zip'
}
m2m_msg = IngestMessage::SQSMessage.new(params)

def extract_zip(zip_file:, extract_dest:)
  Zip::File.open(zip_file) do |zip|
    zip.each do |f|
      f_path = File.join(extract_dest, f.name)
      FileUtils.mkdir_p(File.dirname(f_path))
      zip.extract(f, f_path) unless File.exist?(f_path)
    end
  end
end

RSpec.describe 'M2MInitiateWorker' do # rubocop:disable Metrics/BlockLength
  RSpec::Mocks.configuration.allow_message_expectations_on_nil = true
  # let(:depositor) { 'test_depositor' }
  # let(:collection) { 'test_collection' }
  # let(:resource_path) do
  #   File.join(File.dirname(__FILE__), 'resources', 'm2m')
  # end
  # let(:test_zip) { File.join(resource_path, 'test.zip') }
  # let(:package_zip_dir) { File.join(resource_path, 'package_zip_dir') }
  # let(:package_extract_dir) { File.join(resource_path, 'package_extract_dir') }
  # let(:ingest_root) { File.join(resource_path, 'ingest_root') }
  # let(:sfs_root) { File.join(resource_path, 'sfs_root') }
  # let(:m2m_msg) do
  #   IngestMessage.new({
  #                       type: IngestMessage::TYPE_M2M,
  #                       ingest_id: 'TEST1234', original_msg: nil, dest_path: '',
  #                       depositor: depositor, collection: collection, ingest_manifest: '',
  #                       ticket_id: 'BOGUS-1234',
  #                       package: 'test.zip'
  #                     })
  # end
  let(:storage_schema) do
    File.join(File.dirname(__FILE__), 'resources', 'schema', 'manifest_schema_storage.json')
  end
  let(:ingest_schema) do
    File.join(File.dirname(__FILE__), 'resources', 'schema', 'manifest_schema_ingest.json')
  end
  let(:manifest_validator) do
    Manifests::ManifestValidator.new(ingest_schema: ingest_schema,
                                     storage_schema: storage_schema)
  end
  let(:m2m_initiate_worker) do
    s3_manager = spy('s3_manager')
    allow(s3_manager).to receive(:upload_file)
      .with("#{depositor}/#{collection}/1/one.txt", anything) { true }
    allow(s3_manager).to receive(:upload_file)
      .with("#{depositor}/#{collection}/2/two.txt", anything) { true }
    allow(s3_manager).to receive(:upload_string)
      .with(any_args)
      .and_raise(IngestException, 'upload_string must not be called in this test!')
    # (s3_key: msg.package, dest_path: zip_dest_path)
    allow(s3_manager).to receive(:download_m2m_file)
      .with(any_args) do
      dest_zip = File.join(package_zip_dir, zip_filename)
      FileUtils.copy(test_zip, dest_zip)
    end
    # allow(@s3_manager).to receive(:manifest_key)
    #   .with(ingest_id, Workers::TYPE_INGEST) { ingest_manifest_s3_key }
    # WorkQueuer::M2MIngestQueuer.new(confirm: false)
    queuer = spy('queuer')
    allow(queuer).to receive(:queue_ingest).with(any_args) { true }
    named_params = {
      s3_manager: s3_manager,
      package_zip_dir: package_zip_dir,
      package_extract_dir: package_extract_dir,
      ingest_root: ingest_root,
      sfs_root: sfs_root,
      queuer: queuer,
      manifest_validator: manifest_validator
    }
    M2MWorker::M2MInitiateWorker.new(named_params)
  end

  # enable this test after putting right steward steward for eCommons
  # context 'when it works' do
  #   it 'it works' do
  #     work_path = File.join(package_extract_dir, zip_filename)
  #     FileUtils.remove_dir(path) unless Dir.exist?(work_path)
  #     status = m2m_initiate_worker.work(m2m_msg)
  #     expect(status).to be_truthy
  #   end
  # end

  context 'when preparing package' do
    it 'creates ingest env without merged collection manifest' do
      work_path = File.join(package_extract_dir, zip_filename)
      FileUtils.remove_dir(path) unless Dir.exist?(work_path)
      extract_path = m2m_initiate_worker.prepare_package(msg: m2m_msg)
      expect(extract_path).to eq(File.join(package_extract_dir, zip_filename, depositor, collection))
    end
  end

  # do we need this test?
  # context 'when extracting package' do
  #   it '' do
  #     # test
  #   end
  # end

  # context 'when validating message' do
  #   it 'returns true, change this test when proper validation mechanism is determined' do
  #     # test
  #   end
  # end

  # context 'when reporting error' do
  #   it '' do
  #     # test
  #   end
  # end

  # enable this test after putting right steward steward for eCommons
  # context 'when queueing message' do
  #   it 'invokes queue message function' do
  #     extract_zip(zip_file: test_zip, extract_dest: temp_dir) unless Dir.exist?(temp_extracted_dir)
  #     m2m_initiate_worker.queue_ingest(msg: m2m_msg, path: temp_extracted_dir)
  #     expect(m2m_initiate_worker.queuer).to have_received(:queue_ingest).exactly(1).times
  #   end
  # end

  context 'when generating ingest manifest from package' do
    it 'creates manifest from extracted package content' do
      extract_zip(zip_file: test_zip, extract_dest: temp_dir) unless Dir.exist?(temp_extracted_dir)
      handler = m2m_initiate_worker.m2m_package_handler(msg: m2m_msg)
      manifest = handler.ingest_manifest(msg: m2m_msg, path: temp_extracted_dir)
      manifest_file = handler.create_ingest_manifest_file(msg: m2m_msg, manifest: manifest)
      expect(manifest_file).to eq(File.join(ingest_root, zip_filename, 'ingest_manifest.json'))
      expect(manifest.number_packages).to eq(1)
      package = manifest.packages[0]
      expect(package.number_files).to eq(2)
      expect(package.files[0].filepath).to eq('1/one.txt')
      expect(package.files[1].filepath).to eq('2/two.txt')
    end
  end

  context 'when populating files from package' do
    it 'lists file path' do
      extract_zip(zip_file: test_zip, extract_dest: temp_dir) unless Dir.exist?(temp_extracted_dir)
      handler = m2m_initiate_worker.m2m_package_handler(msg: m2m_msg)
      files = handler.populate_files(path: temp_extracted_dir)
      expect(files.size).to be(2)
      expect(files[0].filepath).to eq('1/one.txt')
      expect(files[1].filepath).to eq('2/two.txt')
    end
  end

  context 'when listing files from path' do
    it 'lists each file' do
      path = File.join(sfs_root, depositor, collection)
      handler = m2m_initiate_worker.m2m_package_handler(msg: m2m_msg)
      files = handler.list_files(path: path)
      expect(files.size).to be(1)
      expect(files[0]).to eq(File.join(sfs_root, depositor, collection,
                                       '_EM_eCommons_eCommons.json.orig'))
    end
  end

  context 'when locating collection manifest' do
    it 'returns none if not found in SFS root' do
      handler = m2m_initiate_worker.m2m_package_handler(msg: m2m_msg)
      expect(handler.collection_manifest(msg: m2m_msg)).to eq('none')
    end

    it 'returns collection manifest path if present in SFS' do
      p1 = File.join(sfs_root, depositor, collection, '_EM_eCommons_eCommons.json.orig')
      p2 = File.join(sfs_root, depositor, collection, '_EM_eCommons_eCommons.json')
      FileUtils.copy(p1, p2)
      handler = m2m_initiate_worker.m2m_package_handler(msg: m2m_msg)
      expect(handler.collection_manifest(msg: m2m_msg)).to eq(p2)
    end
  end

  # context 'when cleaning up' do
  #   it 'removes files and directories recursively' do
  #     zip_copy = File.join(resource_path, 'test_copy.zip')
  #     FileUtils.copy(test_zip, zip_copy)
  #     extract_dest = File.join(resource_path, 'test_path')
  #     extract_zip(zip_file: zip_copy, extract_dest: extract_dest)
  #     m2m_initiate_worker.clean_up(zip_path: zip_copy, extract_dir_path: extract_dest)
  #     expect(File.exist?(zip_copy)).to be false
  #     expect(Dir.exist?(extract_dest)).to be false
  #   end
  # end

  after(:each) do
    dest_zip = File.join(package_zip_dir, zip_filename)
    File.delete(dest_zip) if File.exist?(dest_zip)

    FileUtils.remove_dir(package_extracted_dir) if Dir.exist?(package_extracted_dir)

    temp_manifest_dir = File.join(ingest_root, zip_filename)
    FileUtils.remove_dir(temp_manifest_dir) if Dir.exist?(temp_manifest_dir)

    FileUtils.remove_dir(temp_extracted_dir) if Dir.exist?(temp_extracted_dir)

    p2 = File.join(sfs_root, depositor, collection, '_EM_eCommons_eCommons.json')
    File.delete(p2) if File.exist?(p2)

    zip_copy = File.join(resource_path, 'test_copy.zip')
    File.delete(zip_copy) if File.exist?(zip_copy)
    zip_dest = File.join(resource_path, 'test_path')
    FileUtils.remove_dir(zip_dest) if Dir.exist?(zip_dest)
  end
end
