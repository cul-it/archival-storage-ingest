# frozen_string_literal: true

require 'archival_storage_ingest/ingest_utils/ingest_utils'
require 'archival_storage_ingest/workers/worker'
require 'fileutils'
require 'find'
require 'pathname'

module TransferWorker
  class S3Transferer < Workers::Worker
    # Pass s3_manager only for tests.
    def initialize(s3_manager = nil)
      @s3_manager = s3_manager || ArchivalStorageIngest.configuration.s3_manager
    end

    def name
      'S3 Transferer'
    end

    def work(msg)
      directory_walker = IngestUtils::DirectoryWalker.new

      path_to_trim = Pathname.new(msg.data_path)

      directory_walker.process_immediate_children(msg.effective_data_path) do |path|
        process_path(path, path_to_trim)
      end

      directory_walker.process_rest(msg.effective_data_path) do |path|
        process_path(path, path_to_trim)
      end

      true
    end

    # skip directory
    # upload file
    def process_path(path, path_to_trim)
      return if File.directory?(path)

      s3_key = s3_key(path, path_to_trim)
      @s3_manager.upload_file(s3_key, path)
    end

    def s3_key(path, path_to_trim)
      IngestUtils.relativize(path, path_to_trim)
    end
  end

  class SFSTransferer < Workers::Worker
    def name
      'SFS Transferer'
    end

    def work(msg)
      directory_walker = IngestUtils::DirectoryWalker.new

      path_to_trim = Pathname.new(msg.data_path)

      create_collection_dir(msg, path_to_trim)

      directory_walker.process_immediate_children(msg.effective_data_path) do |path|
        process_path(path, path_to_trim, msg.dest_path)
      end

      directory_walker.process_rest(msg.effective_data_path) do |path|
        process_path(path, path_to_trim, msg.dest_path)
      end

      true
    end

    def create_collection_dir(msg, path_to_trim)
      deposit_root = generate_dest_path(msg.dest_path, msg.effective_data_path, path_to_trim)
      FileUtils.mkdir_p(deposit_root) unless File.exist?(deposit_root)
    end

    # create directory if doesn't exist
    # copy file
    def process_path(path, path_to_trim, dest_root)
      dest = generate_dest_path(dest_root, path, path_to_trim)

      if File.directory?(path)
        FileUtils.mkdir(dest) unless File.exist?(dest)
      else
        FileUtils.copy(path, dest)
      end
    end

    # Example
    # dest_root - /a
    # path - /b/c/d/resource.txt
    # path_to_trim - /b/c
    # return - /a/d/resource.txt
    def generate_dest_path(dest_root, path, path_to_trim)
      File.join(dest_root, Pathname.new(path).relative_path_from(path_to_trim).to_s)
    end
  end
end
