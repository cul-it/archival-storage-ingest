# frozen_string_literal: true

require 'rspec'
require 'spec_helper'
require 'archival_storage_ingest/disseminate/request'
require 'archival_storage_ingest/disseminate/transferer'
require 'archival_storage_ingest/disseminate/fixity_checker'
require 'archival_storage_ingest/disseminate/packager'
require 'archival_storage_ingest/disseminate/disseminator'
require 'zip'

RSpec.describe 'Disseminator' do
  let(:depositor) { 'RMC/RMA' }
  let(:collection) { 'RMA01234' }
  let(:test_package_id) { 'fixity_temporary_package' }
  let(:disseminate_dir) { File.join(File.dirname(__FILE__), 'resources', 'disseminate') }
  let(:target_dir) { File.join(disseminate_dir, 'dest') }
  let(:csv_file) { File.join(disseminate_dir, 'Retrieval_RMA01234_20200715.csv') }
  let(:bad_csv_file) { File.join(disseminate_dir, 'Bad_Retrieval_RMA01234_20200715.csv') }
  let(:archival_bucket) { 'archival0x' }
  let(:sfs_prefix) { File.join(disseminate_dir, archival_bucket) }
  let(:zip_filename) { 'Disseminate_RMM01234_20200715.zip' }
  let(:zip_filepath) { File.join(target_dir, zip_filename) }
  let(:manifest_file) { File.join(sfs_prefix, 'RMC', 'RMA', 'RMA01234', '_EM_RMC_RMA_RMA01234.json') }
  let(:abs_path_file1) { File.join(sfs_prefix, 'RMC/RMA/RMA01234/1/one.txt') }
  let(:abs_path_file2) { File.join(sfs_prefix, 'RMC/RMA/RMA01234/2/two.txt') }
  let(:abs_path_file3) { File.join(sfs_prefix, 'RMC/RMA/RMA01234/3/three.txt') }
  let(:manager) { LocalManager.new(local_root: disseminate_dir, type: TYPE_S3) }
  let(:disseminate_request) do
    Disseminate::Request.new(manifest: manifest_file, csv: csv_file)
  end
  let(:transferred_packages) do
    {
      test_package_id => {
        '1/one.txt' => abs_path_file1,
        '2/two.txt' => abs_path_file2,
        '3/three.txt' => abs_path_file2
      }
    }
  end

  describe 'Disseminate request' do
    context 'When input does not validate' do
      it 'returns false with errors' do
        request = Disseminate::Request.new(manifest: manifest_file, csv: bad_csv_file)
        status = request.validate
        expect(status).to be_falsey
        expect(request.error).not_to eq('')
      end
    end

    context 'When input validates' do
      it 'returns true with no errors' do
        status = disseminate_request.validate
        expect(status).to be_truthy
        expect(disseminate_request.error).to eq('')
      end
    end
  end

  # describe 'Disseminate transferer' do
  #   context 'For SFS disseminate transferer' do
  #     it 'does not copy but reference the original files and populates list for later use' do
  #       sfs_transferer = Disseminate::SFSTransferer.new(sfs_prefix: disseminate_dir, sfs_bucket: archival_bucket)
  #       sfs_transferer.transfer(request: disseminate_request, depositor:, collection:)
  #       expect(sfs_transferer.transferred_packages.size).to eq(1)
  #       package = sfs_transferer.transferred_packages[test_package_id]
  #       expect(package.size).to eq(3)
  #       expect(package['1/one.txt']).to eq(abs_path_file1)
  #       expect(package['2/two.txt']).to eq(abs_path_file2)
  #       expect(package['3/three.txt']).to eq(abs_path_file3)
  #     end
  #   end
  # end

  describe 'Disseminate fixity checker' do
    context 'When checking fixity fails' do
      it 'returns false and populates error' do
        fixity_checker = Disseminate::DisseminationFixityChecker.new
        bad_transferred_packages = {
          test_package_id => {
            '1/one.txt' => abs_path_file1,
            '2/two.txt' => abs_path_file2,
            '3/three.txt' => abs_path_file2
          }
        }
        status = fixity_checker.check_fixity(request: disseminate_request,
                                             transferred_packages: bad_transferred_packages)
        expect(status).to be_falsey
        expect(fixity_checker.error).not_to eq('')
      end
    end

    context 'When checking fixity succeeds' do
      it 'returns true' do
        fixity_checker = Disseminate::DisseminationFixityChecker.new
        transferred_packages = {
          test_package_id => {
            '1/one.txt' => abs_path_file1,
            '2/two.txt' => abs_path_file2,
            '3/three.txt' => abs_path_file3
          }
        }
        status = fixity_checker.check_fixity(request: disseminate_request, transferred_packages:)
        expect(status).to be_truthy
        expect(fixity_checker.error).to eq('')
      end
    end
  end

  describe 'Disseminate packager' do
    after do
      FileUtils.rm_f(zip_filepath)
    end

    context 'When packaging dissemination' do
      it 'zips transferred files' do
        packager = Disseminate::Packager.new
        packager.package_dissemination(zip_filepath:, depositor:,
                                       collection:, transferred_packages:)
        entries = {}
        Zip::File.open(zip_filepath) do |zip_file|
          # Handle entries one by one
          zip_file.each do |entry|
            entries[entry.name] = 1 if entry.file?
          end
        end
        expected_entries = {
          'RMC/RMA/RMA01234/1/one.txt' => 1,
          'RMC/RMA/RMA01234/2/two.txt' => 1,
          'RMC/RMA/RMA01234/3/three.txt' => 1
        }
        expect(entries).to eq(expected_entries)
      end
    end
  end

  describe 'Disseminator' do
    after do
      FileUtils.rm_f(zip_filepath)
    end

    context 'When disseminating request' do
      it 'checks input, transfers assets, runs fixity and packages into zip' do
        disseminator = Disseminate::Disseminator.new(cloud_platform: 'Local', sfs_prefix: ,  default_manager: manager)
        dissemination = disseminator.disseminate(manifest: manifest_file, csv: csv_file,
                                                 depositor:, collection:, zip_filepath:)
        expect(dissemination).to eq(zip_filepath)
        entries = {}
        Zip::File.open(zip_filepath) do |zip_file|
          # Handle entries one by one
          zip_file.each do |entry|
            entries[entry.name] = 1 if entry.file?
          end
        end
        expected_entries = {
          'RMC/RMA/RMA01234/1/one.txt' => 1,
          'RMC/RMA/RMA01234/2/two.txt' => 1,
          'RMC/RMA/RMA01234/3/three.txt' => 1
        }
        expect(entries).to eq(expected_entries)
      end
    end
  end
end
