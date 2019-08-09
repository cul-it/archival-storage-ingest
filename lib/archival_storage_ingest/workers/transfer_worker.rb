# frozen_string_literal: true

require 'archival_storage_ingest/ingest_utils/ingest_utils'
require 'archival_storage_ingest/manifests/manifests'
require 'archival_storage_ingest/workers/worker'
require 'fileutils'
require 'find'
require 'pathname'

module TransferWorker
  class TransferWorker < Workers::Worker
    attr_reader :s3_manager
    # Pass s3_manager only for tests.
    def initialize(s3_manager = nil)
      @s3_manager = s3_manager || ArchivalStorageIngest.configuration.s3_manager
    end

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
        source = source(msg: msg, source_path: source_path, file: file)
        target = target(msg: msg, file: file)
        process_file(source: source, target: target)
      end
    end

    def source(msg:, source_path:, file:)
      File.join(source_path, msg.depositor, msg.collection, file.filepath)
    end

    def target(msg:, file:); end

    def process_file(source:, target:); end
  end

  class S3Transferer < TransferWorker
    def name
      'S3 Transferer'
    end

    # source is absolute file path of the asset
    # target is s3_key
    def process_file(source:, target:)
      s3_manager.upload_file(target, source)
    end

    def target(msg:, file:)
      "#{msg.depositor}/#{msg.collection}/#{file.filepath}"
    end
  end

  class SFSTransferer < TransferWorker
    def name
      'SFS Transferer'
    end

    def process_file(source:, target:)
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.copy(source, target)
    end

    def target(msg:, file:)
      File.join(msg.dest_path, msg.depositor, msg.collection, file.filepath)
    end
  end
end
