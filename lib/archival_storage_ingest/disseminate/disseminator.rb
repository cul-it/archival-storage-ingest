# frozen_string_literal: true

require 'archival_storage_ingest/exception/ingest_exception'
require 'archival_storage_ingest/disseminate/request'
require 'archival_storage_ingest/disseminate/transferer'
require 'archival_storage_ingest/disseminate/fixity_checker'
require 'archival_storage_ingest/disseminate/packager'

module Disseminate
  SFS_SOURCE_LOCATION = 'SFS'
  DEFAULT_SOURCE_LOCATION = 'Wasabi'
  DEFAULT_TARGET_DIR = '/cul/data/ingest_share/DISSEMINATE'

  class Disseminator
    def initialize(source_location: DEFAULT_SOURCE_LOCATION,
                   target_dir: DEFAULT_TARGET_DIR)
      @source_location = source_location
      @target_dir = target_dir
    end

    def disseminate(manifest:, csv:, zip_filename:, depositor:, collection:)
      request = Request.new(manifest:, csv:)
      raise IngestException, request.error unless request.validate

      transferer = init_transferer
      transferer.transfer(request:, depositor:, collection:)

      fixity_checker = init_fixity_checker
      raise IngestException, fixity_checker.error unless
        fixity_checker.check_fixity(request:, transferred_packages: transferer.transferred_packages)

      package_dissemination(transferred_packages: transferer.transferred_packages, depositor:,
                            collection:, zip_filename:)
    end

    def package_dissemination(transferred_packages:, zip_filename:, depositor:, collection:)
      packager = init_packager
      packager.package_dissemination(zip_filepath: File.join(@target_dir, zip_filename),
                                     depositor:, collection:,
                                     transferred_packages:)
    end

    def init_transferer
      return SFS_SOURCE_LOCATION.new(sfs_prefix: @sfs_prefix, sfs_bucket: @sfs_bucket) if
        @source_location.eql?(DEFAULT_SOURCE_LOCATION)

      WasabiTransferer.new
    end

    def init_fixity_checker
      return SFSFixityChecker.new if @source_location.eql?(DEFAULT_SOURCE_LOCATION)
    end

    def init_packager
      return SFSPackager.new if @source_location.eql?(DEFAULT_SOURCE_LOCATION)
    end
  end
end
