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
  # The Disseminator class is responsible for managing the dissemination process.
  # It initializes with a platform, sfs_prefix, and default manager (for testing), and provides methods
  # to disseminate files, package the dissemination, and initialize a transferer.
  class Disseminator
    # Initializes a new Disseminator
    #
    # @param [String] cloud_platform The cloud platform to use for the dissemination
    # (i.e., S3 or Wasabi at this point)
    # @param [String] sfs_prefix The prefix to use for local file paths
    # @param [S3Manager] default_manager The default manager for testing (presumably a LocalManager)
    def initialize(cloud_platform:, sfs_prefix: '.', default_manager: nil)
      @cloud_platform = cloud_platform
      @default_manager = default_manager
      @sfs_prefix = sfs_prefix
    end

    # Disseminates files based on the given parameters.
    # It validates the request, transfers the files, checks the fixity, and packages the dissemination.
    #
    # @param [String] manifest The manifest file.
    # @param [String] csv The CSV file used by the Request to identify the files to disseminate.
    # @param [String] zip_filename The name of the ZIP file.
    # @param [String] depositor The name of the depositor.
    # @param [String] collection The name of the collection.
    def disseminate(manifest:, csv:, zip_filename:, depositor:, collection:)
      request = Request.new(manifest:, csv:)
      raise IngestException, request.error unless request.validate

      transferer = init_transferer
      transferer.transfer(request:, depositor:, collection:)

      fixity_checker = DisseminationFixityChecker.new
      raise IngestException, fixity_checker.error unless
        fixity_checker.check_fixity(request:, transferred_packages: transferer.transferred_packages)

      package_dissemination(transferred_packages: transferer.transferred_packages, depositor:,
                            collection:, zip_filename:)
    end

    # Packages the disseminated files into a ZIP file.
    #
    # @param [Hash] transferred_packages The packages that have been transferred.
    # @param [String] zip_filename The name of the ZIP file.
    # @param [String] depositor The name of the depositor.
    # @param [String] collection The name of the collection.
    def package_dissemination(transferred_packages:, zip_filename:, depositor:, collection:)
      Packager.new.package_dissemination(zip_filepath: zip_filename,
                                         depositor:, collection:,
                                         transferred_packages:)
    end

    # Initializes a CloudTransferer with a S3Manager or WasabiManager to transfer files from a cloud source.
    #
    # @return [CloudTransferer] The initialized CloudTransferer.
    def init_transferer
      bucket = IngestUtils::CLOUD_PLATFORM_TO_BUCKET_NAME[@cloud_platform]
      cloud_manager = if @cloud_platform == IngestUtils::PLATFORM_WASABI
                        WasabiManager.new(bucket)
                      elsif @cloud_platform == IngestUtils::PLATFORM_LOCAL
                        @default_manager
                      else
                        S3Manager.new(bucket)
                      end
      CloudTransferer.new(cloud_manager:, sfs_prefix: @sfs_prefix)
    end
  end
end
