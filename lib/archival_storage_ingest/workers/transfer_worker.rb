# frozen_string_literal: true

require 'archival_storage_ingest/ingest_utils/ingest_utils'
require 'archival_storage_ingest/manifests/manifests'
require 'archival_storage_ingest/messages/ingest_message'
require 'archival_storage_ingest/workers/worker'
require 'fileutils'
require 'find'
require 'pathname'

module TransferWorker
  class TransferWorker < Workers::Worker
    attr_reader :s3_manager, :issue_logger

    # Pass s3_manager and issue_logger only for tests.
    def initialize(s3_manager = nil, issue_logger = nil)
      super(_name)
      @s3_manager = s3_manager || ArchivalStorageIngest.configuration.s3_manager
      @issue_logger = issue_logger || ArchivalStorageIngest.configuration.issue_logger
    end

    def _name; end

    def work(msg)
      ingest_manifest = fetch_ingest_manifest(msg)
      ingest_manifest.walk_packages do |package|
        process_package(package: package, msg: msg)
      end

      true
    end

    def fetch_ingest_manifest(msg)
      manifest_s3_key = s3_manager.manifest_key(msg.ingest_id, Workers::TYPE_INGEST)
      ingest_manifest = s3_manager.retrieve_file(manifest_s3_key)
      Manifests::Manifest.new(json_text: ingest_manifest.string)
    end

    def process_package(package:, msg:)
      source_path = package.source_path
      package.walk_files do |file|
        source = source(source_path: source_path, file: file)
        target = target(msg: msg, file: file)
        notify_transfer_started(ingest_msg: msg, file: file)
        process_file(source: source, target: target)
        notify_transfer_completed(ingest_msg: msg, file: file)
      end
    end

    def source(source_path:, file:)
      File.join(source_path, file.filepath)
    end

    def target(msg:, file:); end

    def process_file(source:, target:); end

    def notify_transfer_started(ingest_msg:, file:)
      identifier = "#{ingest_msg.depositor}/#{ingest_msg.collection}/#{file.filepath}"
      params = {
        log: "Transfer of '#{ingest_msg.depositor}/#{ingest_msg.collection}/#{file.filepath}' to #{platform} has started",
        log_identifier: identifier, log_report_to_jira: false, log_status: 'Started', log_timestamp: IngestUtils.utc_time
      }
      issue_logger.notify_worker_started(ingest_msg: ingest_msg, params: params)
    end

    def notify_transfer_completed(ingest_msg:, file:)
      identifier = "#{ingest_msg.depositor}/#{ingest_msg.collection}/#{file.filepath}"
      params = {
        log: "Transfer of '#{ingest_msg.depositor}/#{ingest_msg.collection}/#{file.filepath}' to #{platform} has completed",
        log_identifier: identifier, log_report_to_jira: false, log_status: 'Started', log_timestamp: IngestUtils.utc_time
      }
      issue_logger.notify_worker_completed(ingest_msg: ingest_msg, params: params)
    end
  end

  class S3Transferer < TransferWorker
    def _name
      'S3 Transferer'
    end

    def platform
      IngestMessage::PLATFORM_S3
    end

    # source is absolute file path of the asset
    # target is s3_key
    def process_file(source:, target:)
      s3_manager.upload_file(target, source)
    end

    # needs to be updated when we adopt OCFL
    def target(msg:, file:)
      "#{msg.depositor}/#{msg.collection}/#{file.filepath}"
    end
  end

  class SFSTransferer < TransferWorker
    def _name
      'SFS Transferer'
    end

    def platform
      IngestMessage::PLATFORM_SFS
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
