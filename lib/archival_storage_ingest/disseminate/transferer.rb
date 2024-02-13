# frozen_string_literal: true

require 'archival_storage_ingest/exception/ingest_exception'

module Disseminate
  class BaseTransferer
    attr_reader :transferred_packages

    def initialize
      @transferred_packages = {}
    end

    def transfer(request:, depositor:, collection:); end
  end

  class SFSTransferer < BaseTransferer
    def initialize(sfs_prefix:, sfs_bucket:)
      super()
      @sfs_prefix = File.join(sfs_prefix, sfs_bucket)
    end

    # For SFS, it won't copy, but use the SFS asset directly
    # Populate files with SFS copies so that it can be populated for later use
    def transfer(request:, depositor:, collection:)
      request.walk_packages do |package_id, package|
        package.each do |disseminate_file|
          @transferred_packages[package_id] = {} if @transferred_packages[package_id].nil?

          @transferred_packages[package_id][disseminate_file[:filepath]] =
            File.join(@sfs_prefix, depositor, collection, disseminate_file[:filepath])
        end
      end
    end
  end

  class WasabiTransferer < BaseTransferer
    def initialize(wasabi_manager)
      super()
      @wasabi_manager = wasabi_manager
    end

    # Transfers files from Wasabi based on the given request.
    # The files are downloaded to a location based on the depositor and collection.
    # The paths of the transferred files are stored in the @transferred_packages hash.
    #
    # @param [Request] request The request object that contains the packages to transfer
    # @param [String] depositor Name of the depositor
    # @param [String] collection Name of the collection
    def transfer(request:, depositor:, collection:)
      request.walk_packages do |package_id, package|
        package.each do |file|
          @transferred_packages[package_id] = {} if @transferred_packages[package_id].nil?

          source = File.join(depositor, collection, file[:filepath])
          target = File.join(depositor, collection, file[:filepath])

          @wasabi_manager.download_file(s3_key: source, dest_path: target)

          @transferred_packages[package_id][file[:filepath]] = target
        end
      end
    end
  end
end
