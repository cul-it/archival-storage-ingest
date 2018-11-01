# frozen_string_literal: true

require 'archival_storage_ingest/workers/worker'
require 'fileutils'
require 'find'
require 'pathname'

module TransferWorker
  EXCLUDE_FILE_LIST = {
    '.DS_Store' => true,
    '.Thumbs.db' => true,
    '.BridgeCache' => true,
    '.BridgeCacheT' => true
  }.freeze

  # https://stackoverflow.com/questions/357754/can-i-traverse-symlinked-directories-in-ruby-with-a-glob
  # I was able to follow symlink with Dir.glob('**/*/**')
  # As was mentioned in the link above, it DOES NOT give you the immediate children (dir or file).
  # I could not get the "fix" to work **{,/*/**}/*.
  # If I use **{,/*/**}/*, I get files in non-symlink'ed directories twice.
  # I will process immediate children and then use **/*/**.

  class BaseTransferWorker < Workers::Worker
    def work(msg)
      path_to_trim = Pathname.new(msg.data_path)

      pre_process(msg, path_to_trim)

      process_immediate_children(msg, path_to_trim)

      process_rest(msg, path_to_trim)

      true
    end

    # For sfs worker, this is where it will try to create root depositor / collection
    # if it doesn't exist.
    def pre_process(_msg, _path_to_trim) end

    def process_immediate_children(msg, path_to_trim)
      Dir.glob("#{msg.effective_data_path}/*").each do |path|
        next if EXCLUDE_FILE_LIST[File.basename(path)]

        process_path(path, path_to_trim, msg)
      end
    end

    def process_rest(msg, path_to_trim)
      Dir.glob("#{msg.effective_data_path}/**/*/**").each do |path|
        next if EXCLUDE_FILE_LIST[File.basename(path)]

        process_path(path, path_to_trim, msg)
      end
    end

    # For s3 worker, only upload file.
    # For sfs worker, create directory if doesn't exist or copy file.
    def process_path(_path, _path_to_trim, _msg) end
  end

  class S3Transferer < BaseTransferWorker
    # Pass s3_manager only for tests.
    def initialize(s3_manager = nil)
      @s3_manager = s3_manager || ArchivalStorageIngest.configuration.s3_manager
    end

    # s3 worker doesn't use msg argument
    # skip directory
    # upload file
    def process_path(path, path_to_trim, _msg)
      return if File.directory?(path)

      s3_key = get_s3_key(path, path_to_trim)
      @s3_manager.upload_file(s3_key, path)
    end

    # Example arguments
    # file - /a/b/c/resource.txt
    # path_to_trim - /a/b
    # s3 key - c/resource.txt
    def get_s3_key(file, path_to_trim)
      Pathname.new(file).relative_path_from(path_to_trim).to_s
    end

    def upload_file(s3_key, file_to_upload)
      @s3_manager.upload_file(s3_key, file_to_upload)
    end
  end

  class SFSTransferer < BaseTransferWorker
    def pre_process(msg, path_to_trim)
      deposit_root = get_dest_path(msg.dest_path, msg.effective_data_path, path_to_trim)
      FileUtils.mkdir_p(deposit_root) unless File.exist?(deposit_root)
    end

    # create directory if doesn't exist
    # copy file
    def process_path(path, path_to_trim, msg)
      dest = get_dest_path(msg.dest_path, path, path_to_trim)

      if File.directory?(path)
        FileUtils.mkdir dest unless File.exist? dest
      else
        FileUtils.copy path, dest
      end
    end

    # Example
    # dest_root - /a
    # path - /b/c/d/resource.txt
    # path_to_trim - /b/c
    # return - /a/d/resource.txt
    def get_dest_path(dest_root, path, path_to_trim)
      File.join(dest_root, Pathname.new(path).relative_path_from(path_to_trim).to_s)
    end
  end
end
