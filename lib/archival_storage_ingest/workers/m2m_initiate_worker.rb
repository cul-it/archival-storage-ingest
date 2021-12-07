# frozen_string_literal: true

require 'archival_storage_ingest/ingest_utils/ingest_utils'
require 'archival_storage_ingest/manifests/manifests'
require 'archival_storage_ingest/preingest/base_env_initializer'
require 'archival_storage_ingest/preingest/ingest_env_initializer'
require 'archival_storage_ingest/work_queuer/work_queuer'
require 'archival_storage_ingest/workers/worker'
require 'archival_storage_ingest/workers/package_handler/ecommons_package_handler'
require 'fileutils'
require 'find'
require 'json'
require 'pathname'
require 'zip'

module M2MWorker
  class M2MInitiateWorker < Workers::Worker
    attr_reader :s3_manager, :package_zip_dir, :package_extract_dir,
                :ingest_root, :sfs_root, :queuer, :manifest_validator,
                :file_identifier

    # For test, we specify validator and identifier to use different values than default.
    # We don't want them initialized with default value for tests.
    # As such, we can't just use named_params.fetch(:abc, ABC.new) for those two.
    # The way fetch(a, default_value) works is that the default_value is initialized even when it is not used.
    def initialize(named_params)
      super(_name)
      @s3_manager = named_params.fetch(:s3_manager) { ArchivalStorageIngest.configuration.s3_manager }
      @package_zip_dir = named_params.fetch(:package_zip_dir)
      @package_extract_dir = named_params.fetch(:package_extract_dir)
      @ingest_root = named_params.fetch(:ingest_root)
      @sfs_root = named_params.fetch(:sfs_root)
      @queuer = named_params.fetch(:queuer, WorkQueuer::M2MIngestQueuer.new(confirm: false))
      @manifest_validator = _fetch_manifest_validator(params: named_params)
      @file_identifier = _fetch_file_identifier(params: named_params)
    end

    def _fetch_manifest_validator(params:)
      if params.key?(:manifest_validator)
        params.fetch(:manifest_validator)
      else
        Manifests::ManifestValidator.new
      end
    end

    def _fetch_file_identifier(params:)
      if params.key?(:file_identifier)
        params.fetch(:file_identifier)
      else
        Manifests::FileIdentifier.new
      end
    end

    def _name
      'M2M Ingest Initiator'
    end

    def work(msg)
      path = prepare_package(msg: msg)
      handler = m2m_package_handler(msg: msg)
      handler.queue_ingest(msg: msg, path: path)

      true
    end

    def prepare_package(msg:)
      zip_dest_path = File.join(package_zip_dir, msg.package)
      s3_manager.download_m2m_file(s3_key: msg.package, dest_path: zip_dest_path)
      extract_dest_path = File.join(package_extract_dir, msg.package, msg.depositor, msg.collection)
      FileUtils.mkdir_p(extract_dest_path)
      extract_package(zip_dest_path: zip_dest_path, extract_dest_path: extract_dest_path)
      extract_dest_path
    end

    def extract_package(zip_dest_path:, extract_dest_path:)
      Zip::File.open(zip_dest_path) do |zip_file|
        zip_file.each do |f|
          f_path = File.join(extract_dest_path, f.name)
          FileUtils.mkdir_p(File.dirname(f_path))
          zip_file.extract(f, f_path) unless File.exist?(f_path)
        end
      end
    end

    def m2m_package_handler(msg:)
      if ecommons?(msg: msg)
        return M2MWorker::ECommonsPackageHandler.new(ingest_root: ingest_root, sfs_root: sfs_root,
                                                     file_identifier: file_identifier,
                                                     manifest_validator: manifest_validator,
                                                     queuer: queuer)
      end

      raise IngestException, "Package handler not found for #{msg.depositor}/#{msg.collection}"
    end

    ECOMMONS_DEPOSITOR = 'eCommons'
    ECOMMONS_COLLECTION = 'eCommons'
    def ecommons?(msg:)
      msg.depositor == ECOMMONS_DEPOSITOR && msg.collection == ECOMMONS_COLLECTION
    end
  end
end
