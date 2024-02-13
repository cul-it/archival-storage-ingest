# frozen_string_literal: true

require 'archival_storage_ingest/exception/ingest_exception'
require 'archival_storage_ingest/disseminate/request'
require 'archival_storage_ingest/disseminate/transferer'
require 'archival_storage_ingest/disseminate/fixity_checker'
require 'archival_storage_ingest/disseminate/packager'
require 'archival_storage_ingest/wasabi/wasabi_manager'

module Disseminate
  DEFAULT_SOURCE_LOCATION = 'Wasabi'
  DEFAULT_TARGET_DIR = '/cul/data/ingest_share/DISSEMINATE'

  # The Disseminator class is responsible for managing the dissemination process.
  # It initializes with a source location and a target directory, and provides methods
  # to disseminate files, package the dissemination, and initialize a transferer.
  #
  # @attr_reader [String] source_location The location of the source files.
  # @attr_reader [String] target_dir The directory where the files will be transferred.
  class Disseminator
    # Initializes a new Disseminator
    #
    # @param [String] source_location The location of the source files.
    # @param [String] target_dir The directory to which the files will be transferred.
    def initialize(source_location: DEFAULT_SOURCE_LOCATION,
                   target_dir: DEFAULT_TARGET_DIR)
      @source_location = source_location
      @target_dir = target_dir
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
      DisseminationPackager.new.package_dissemination(zip_filepath: File.join(@target_dir, zip_filename),
                                                      depositor:, collection:,
                                                      transferred_packages:)
    end

    # Initializes a WasabiTransferer with a WasabiManager to transfer files from Wasabi.
    # The Wasabi bucket is determined based on the environment variables that may be set for testing.
    #
    # @return [WasabiTransferer] The initialized WasabiTransferer.
    def init_transferer
      # TODO: get bucket from exe invocation
      wasabi_bucket = ENV['asi_develop'] || ENV['asi_disseminate_develop'] ? 'wasabi-cular-dev' : 'wasabi-cular'
      wasabi_manager = WasabiManager.new(wasabi_bucket)
      WasabiTransferer.new(wasabi_manager)
    end
  end
end
