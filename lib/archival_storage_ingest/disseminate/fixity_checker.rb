# frozen_string_literal: true

require 'archival_storage_ingest/exception/ingest_exception'
require 'archival_storage_ingest/ingest_utils/ingest_utils'

module Disseminate
  class DisseminationFixityChecker
    def initialize
      @errors = []
    end

    def check_fixity(request:, transferred_packages:)
      request.walk_packages do |package_id, package|
        transferred_package = transferred_packages[package_id]
        package.each do |request_file|
          transferred_file = transferred_package[request_file[:filepath]]
          check_fixity_file(request_file:, transferred_file:)
        end
      end

      @errors.empty?
    end

    def check_fixity_file(request_file:, transferred_file:)
      request_fixity = request_file[:fixity]
      transferred_fixity, _size = IngestUtils.calculate_checksum(filepath: transferred_file)
      @errors << "Fixity mismatch #{request_file[:filepath]} : #{request_fixity} : #{transferred_fixity}" unless
        request_fixity.eql?(transferred_fixity)
    end

    def error
      @errors.join("\n")
    end
  end
end
