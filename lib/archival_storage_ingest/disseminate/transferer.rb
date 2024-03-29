# frozen_string_literal: true

require 'archival_storage_ingest/exception/ingest_exception'

module Disseminate
  class CloudTransferer
    attr_reader :transferred_packages

    def initialize(cloud_manager:, local_file_prefix:)
      @cloud_manager = cloud_manager
      @transferred_packages = {}
      @local_file_prefix = local_file_prefix
    end

    def transfer(request:, depositor:, collection:)
      request.walk_packages do |package_id, package|
        package.each do |file|
          @transferred_packages[package_id] ||= {}
          source = File.join(depositor, collection, file[:filepath])
          target = File.join(@local_file_prefix, source)

          @cloud_manager.download_file(s3_key: source, dest_path: target)
          @transferred_packages[package_id][file[:filepath]] = target
        end
      end
    end
  end
end
