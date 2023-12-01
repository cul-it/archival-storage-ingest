# frozen_string_literal: true

require 'archival_storage_ingest/exception/ingest_exception'

module Disseminate
  class CloudTransferer
    attr_reader :transferred_packages

    def initialize(cloud_manager:)
      @cloud_manager = cloud_manager
      @transferred_packages = {}
    end

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
end
