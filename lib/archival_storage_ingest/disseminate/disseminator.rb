# frozen_string_literal: true

require 'archival_storage_ingest/exception/ingest_exception'
require 'archival_storage_ingest/ingest_utils/ingest_utils'
require 'archival_storage_ingest/disseminate/request'
require 'archival_storage_ingest/disseminate/transferer'
require 'archival_storage_ingest/disseminate/fixity_checker'
require 'archival_storage_ingest/disseminate/packager'
require 'archival_storage_ingest/s3/s3_manager'
require 'archival_storage_ingest/wasabi/wasabi_manager'

module Disseminate
  class Disseminator
    def initialize(cloud_platform:)
      @cloud_platform = cloud_platform
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
      packager.package_dissemination(zip_filepath: zip_filename,
                                     depositor:, collection:,
                                     transferred_packages:)
    end

    def init_transferer
      bucket = IngestUtils.CLOUD_PLATFORM_TO_BUCKET_NAME[@cloud_platform]
      cloud_manager = if @cloud_platform == IngestUtils.PLATFORM_WASABI
                        WasabiManager(bucket)
                      else
                        S3Manager(bucket)
                      end
      CloudTransferer.new(cloud_manager:)
    end

    def init_fixity_checker
      DisseminationFixityChecker.new
    end

    def init_packager
      Packager.new
    end
  end
end
