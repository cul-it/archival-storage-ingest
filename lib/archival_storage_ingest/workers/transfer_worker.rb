# frozen_string_literal: true

require 'archival_storage_ingest/ingest_utils/ingest_utils'
require 'archival_storage_ingest/manifests/manifests'
require 'archival_storage_ingest/workers/worker'
require 'fileutils'
require 'find'
require 'pathname'

module TransferWorker
  class TransferWorker < Workers::Worker
    attr_reader :s3_manager, :wasabi_manager

    # Pass s3_manager or wasabi_manager only for tests.
    def initialize(application_logger, s3_manager = nil, wasabi_manager = nil)
      super(application_logger)
      @s3_manager = s3_manager || ArchivalStorageIngest.configuration.s3_manager
      @wasabi_manager = wasabi_manager || ArchivalStorageIngest.configuration.wasabi_manager
    end

    def _work(msg)
      ingest_manifest = fetch_ingest_manifest(msg)
      ingest_manifest.walk_packages do |package|
        process_package(package:, msg:)
      end

      true
    end

    def fetch_ingest_manifest(msg)
      manifest_s3_key = s3_manager.manifest_key(msg.job_id, Workers::TYPE_INGEST)
      ingest_manifest = s3_manager.retrieve_file(manifest_s3_key)
      Manifests::Manifest.new(json_text: ingest_manifest.string)
    end

    def process_package(package:, msg:)
      source_path = package.source_path
      package.walk_files do |file|
        source = source(source_path:, file:)
        target = target(msg:, file:)
        @application_logger.log(process_file_start_msg(msg:, target:))
        process_file(source:, target:)
        @application_logger.log(process_file_complete_msg(msg:, target:))
      end
    end

    def source(source_path:, file:)
      File.join(source_path, file.filepath)
    end

    def target(msg:, file:); end

    # default behavior works for SFS transfer
    def target_for_log(target)
      target
    end

    def process_file(source:, target:); end

    def process_file_start_msg(msg:, target:)
      {
        job_id: msg.job_id,
        log: "Transfer of #{target_for_log(target)} has started."
      }
    end

    def process_file_complete_msg(msg:, target:)
      {
        job_id: msg.job_id,
        log: "Transfer of #{target_for_log(target)} has completed."
      }
    end
  end

  class S3Transferer < TransferWorker
    def _name
      'S3 Transferer'
    end

    # source is absolute file path of the asset
    # target is s3_key
    def process_file(source:, target:)
      s3_manager.upload_file(target, source)
    end

    def target_for_log(target)
      "s3://#{@s3_manager.s3_bucket}/#{target}"
    end

    # needs to be updated when we adopt OCFL
    def target(msg:, file:)
      "#{msg.depositor}/#{msg.collection}/#{file.filepath}"
    end
  end

  class S3WestTransferer < S3Transferer
    attr_accessor :s3_manifest_manager

    def _name
      'S3 West Transferer'
    end

    # Use cular bucket in the east to fetch ingest manifest
    def fetch_ingest_manifest(msg)
      manifest_s3_key = s3_manifest_manager.manifest_key(msg.job_id, Workers::TYPE_INGEST)
      ingest_manifest = s3_manifest_manager.retrieve_file(manifest_s3_key)
      Manifests::Manifest.new(json_text: ingest_manifest.string)
    end
  end

  class WasabiTransferer < S3Transferer
    def _name
      'Wasabi Transferer'
    end

    # source is absolute file path of the asset
    # target is s3_key
    def process_file(source:, target:)
      wasabi_manager.upload_file(target, source)
    end

    def target_for_log(target)
      "s3://#{@wasabi_manager.s3_bucket}/#{target}"
    end
  end

  class SFSTransferer < TransferWorker
    def _name
      'SFS Transferer'
    end

    def process_file(source:, target:)
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.copy(source, target)
    end

    # needs to be updated when we adopt OCFL
    def target(msg:, file:)
      File.join(msg.dest_path, file.filepath)
    end
  end
end
