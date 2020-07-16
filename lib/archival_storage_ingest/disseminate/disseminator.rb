# frozen_string_literal: true

require 'archival_storage_ingest/exception/ingest_exception'

module Disseminate
  DEFAULT_SFS_PREFIX = '/cul/data'
  DEFAULT_SOURCE_LOCATION = 'SFS'
  DEFAULT_TARGET_DIR = '/cul/data/ingest_share/DISSEMINATE'

  class Disseminator
    def initialize(sfs_prefix: DEFAULT_SFS_PREFIX, source_location: DEFAULT_SOURCE_LOCATION,
                   target_dir: DEFAULT_TARGET_DIR, sfs_bucket: '')
      @sfs_prefix = sfs_prefix
      @source_location = source_location
      @target_dir = target_dir
      @sfs_bucket = sfs_bucket
    end

    def disseminate(manifest:, csv:, zip_filename:, depositor:, collection:)
      request = Request.new(manifest: manifest, csv: csv)
      raise IngestException, request.error unless request.validate

      transferer = init_transferer
      transferer.transfer(request: request, depositor: depositor, collection: collection)

      fixity_checker = init_fixity_checker
      raise IngestException, fixity_checker.error unless
        fixity_checker.check_fixity(request: request, transferred_packages: transferer.transferred_packages)

      package_dissemination(transferred_packages: transferer.transferred_packages, depositor: depositor,
                            collection: collection, zip_filename: zip_filename)
    end

    def package_dissemination(transferred_packages:, zip_filename:, depositor:, collection:)
      packager = init_packager
      packager.package_dissemination(zip_filepath: File.join(@target_dir, zip_filename),
                                     depositor: depositor, collection: collection,
                                     transferred_packages: transferred_packages)
    end

    def init_transferer
      return SFSTransferer.new(sfs_prefix: @sfs_prefix, sfs_bucket: @sfs_bucket) if
        @source_location.eql?(DEFAULT_SOURCE_LOCATION)
    end

    def init_fixity_checker
      return SFSFixityChecker.new if @source_location.eql?(DEFAULT_SOURCE_LOCATION)
    end

    def init_packager
      return SFSPackager.new if @source_location.eql?(DEFAULT_SOURCE_LOCATION)
    end
  end
end
