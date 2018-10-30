# frozen_string_literal: true

require 'archival_storage_ingest/workers/worker'
require 'fileutils'
require 'find'
require 'pathname'

# By default, Find.find or Dir.glob don't follow symlinks.
# Find.find does not follow symlinks at all and I had difficulty working with Dir.glob('**/*/**/b')
#  - listing files twice.
# This implementation will walk through the directory using Find.find and keep a record of symlink'ed directories.
# It will then walk through each symlink'ed directories again but won't process symlinks inside symlinks.
# Since it has to work on the real directory of the symlink, a lot of translation has to take place.
# It is working as intended but we may consider using external system command (rsync and AWS CLI).
module TransferWorker
  EXCLUDE_FILE_LIST = {
    '.DS_Store' => true,
    '.Thumbs.db' => true,
    '.BridgeCache' => true,
    '.BridgeCacheT' => true
  }.freeze

  class S3Transferer < Workers::Worker
    # Pass s3_manager only for tests.
    def initialize(s3_manager = nil)
      @s3_manager = s3_manager || ArchivalStorageIngest.configuration.s3_manager
    end

    def work(msg)
      ## For /cul/data/RMC/..., we want to use RMC/... as object key
      path_to_trim = Pathname.new(msg.data_path).parent

      symlinks = traverse(msg.data_path, path_to_trim)

      symlinks.each do |symlink|
        traverse_symlink(symlink, path_to_trim)
      end

      true
    end

    # Traverse data_path to upload file recursively.
    # It should return an array of symlinked directories.
    def traverse(data_path, path_to_trim)
      symlinks = []
      Find.find(data_path) do |path|
        if File.directory?(path)
          symlinks.push(path) if File.symlink?(path)
          next
        end

        next if EXCLUDE_FILE_LIST[File.basename(path)]

        upload_file(get_s3_key(path, path_to_trim), path)
      end

      symlinks
    end

    def traverse_symlink(symlink, path_to_trim)
      symlink_real_path = Pathname.new(File.realdirpath(symlink))

      Find.find(symlink_real_path) do |path|
        next if File.directory?(path)

        next if EXCLUDE_FILE_LIST[File.basename(path)]

        s3_key = get_s3_key_in_symlinked_dir(path, symlink, symlink_real_path, path_to_trim).to_s
        upload_file(s3_key, path)
      end
    end

    # Example arguments
    # file - /a/b/c/resource.txt
    # path_to_trim - /a/b
    # s3 key - c/resource.txt
    def get_s3_key(file, path_to_trim)
      Pathname.new(file).relative_path_from(path_to_trim).to_s
    end

    # Example arguments
    # file_path    - /a/data/test1/4/stuff.txt
    # symlink      - /a/data/test1/stuff/4
    # symlink_real_path (real path of symlink) - /a/data/test1/4
    # path to trim - /a/data/test1
    # s3 key       - stuff/4/stuff.txt
    def get_s3_key_in_symlinked_dir(file_path, symlink, symlink_real_path, path_to_trim)
      relative_path = Pathname.new(file_path).relative_path_from(symlink_real_path)
      Pathname.new(File.join(symlink, relative_path)).relative_path_from(path_to_trim)
    end

    def upload_file(s3_key, file_to_upload)
      @s3_manager.upload_file(s3_key, file_to_upload)
    end
  end

  class SFSTransferer < Workers::Worker
    def work(msg)
      path_to_trim = Pathname.new(msg.data_path).parent

      symlinks = traverse(msg.data_path, msg.dest_path, path_to_trim)

      symlinks.each do |symlink|
        traverse_symlink(symlink, msg.dest_path, path_to_trim)
      end

      true
    end

    # Traverse data_path to upload file recursively.
    # It should return an array of symlinked directories.
    def traverse(data_root, dest_root, path_to_trim)
      symlinks = []
      Find.find(data_root) do |path|
        next if EXCLUDE_FILE_LIST[File.basename(path)]

        dest = get_dest_path(dest_root, path, path_to_trim)

        symlinks.push(path) if handle_path(path, dest)
      end

      symlinks
    end

    # handles path and returns path if it is symlink directory
    def handle_path(path, dest)
      if File.directory?(path)
        FileUtils.mkdir dest unless File.exist? dest
        path if File.symlink?(path)
      else
        FileUtils.copy path, dest
      end
    end

    def traverse_symlink(symlink, dest_root, path_to_trim)
      symlink_real_path = Pathname.new(File.realdirpath(symlink))
      dest_prefix = Pathname.new(symlink).relative_path_from(path_to_trim)
      dest_root_path = Pathname.new(File.join(dest_root, dest_prefix.to_s))

      Find.find(symlink_real_path) do |path|
        next if EXCLUDE_FILE_LIST[File.basename(path)]

        dest = get_symlinked_dest_path(path, symlink_real_path, dest_root_path)

        handle_path(path, dest)
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

    # Example
    # path - /b/c/d/resource.txt
    # symlink_real_path - /b/c/d
    # dest_root_path - /a/d
    # return - /a/d/resource.txt
    def get_symlinked_dest_path(path, symlink_real_path, dest_root_path)
      relative_path = Pathname.new(path).relative_path_from(symlink_real_path)
      # File.join puts / if relative_path is '.'.
      # We can either trim the trailing / or not join if relative_path is '.'
      relative_path.to_s == '.' ? dest_root_path.to_s : File.join(dest_root_path, relative_path).to_s
    end
  end
end
