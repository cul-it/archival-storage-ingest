# frozen_string_literal: true

require 'csv'
require 'archival_storage_ingest/manifests/manifests'

module Disseminate
  PACKAGE_ID = 'package_id'
  FILEPATH = 'filepath'
  FIXITY = 'sha1'
  SIZE = 'size'

  class Request
    attr_reader :zip_filename

    # Initializes a new Request
    #
    # @param manifest [String] The path and filename of the manifest for the collection being requested
    # @param csv [String] The path to the CSV file that contains the details of the files to be disseminated
    def initialize(manifest:, csv:)
      @manifest = Manifests.read_manifest(filename: manifest)
      init_files(csv)
      @error = []
    end

    # Initializes the files for this request
    #
    # The CSV file should have the following columns:
    # - PACKAGE_ID: The identifier of the package that the file belongs to
    # - FILEPATH: The path of the file within the package
    # - FIXITY: The fixity value of the file
    # - SIZE: The size of the file in bytes
    #
    # Each row in the CSV file represents a file to be disseminated.
    #
    # @param csv [String] The path to the CSV file that contains the details of the files to be disseminated
    def init_files(csv)
      @packages = {}
      CSV.foreach(csv, headers: true) do |row|
        package_id = row.fetch(PACKAGE_ID)
        @packages[package_id] = [] if @packages[package_id].nil?
        @packages[package_id] << { package_id:, filepath: row.fetch(FILEPATH),
                                   fixity: row.fetch(FIXITY), size: row.fetch(SIZE).to_i }
      end
    end

    # Validates the files for this request
    #
    # @return [Boolean] Returns true if the files are valid, false otherwise.
    def validate
      @packages.each do |package_id, package|
        manifest_package = @manifest.get_package(package_id:)
        package.each do |disseminate_file|
          manifest_file = manifest_package.find_file(filepath: disseminate_file[:filepath])
          validate_file(d_file: disseminate_file, m_file: manifest_file)
        end
      end
      @error.empty?
    end

    # Validates a single file for presence, fixity, and size
    #
    # @param d_file [Hash] A hash representing the file to be disseminated
    # @param m_file [File] A File object representing the file in the manifest
    #
    # validate_file does not return a value. Instead, it modifies the `@error` array as a side effect.
    #  After validate_file  is called for all files, you can call the `error` method to get a string containing
    #  all error messages. If the `error` method returns an empty string, it means that all files have been
    #  validated successfully.
    def validate_file(d_file:, m_file:)
      if m_file.nil?
        @error << "#{d_file[:filepath]} in #{d_file[:package_id]} not found in manifest"
      else
        @error << "#{d_file[:filepath]} in #{d_file[:package_id]} does not match" unless
          m_file.sha1.eql?(d_file[:fixity]) && m_file.size == d_file[:size]
      end
    end

    def walk_packages(&)
      @packages.each(&)
    end

    def walk_files(&)
      @packages.each_value do |package|
        package.each(&)
      end
    end

    def error
      @error.join("\n")
    end
  end
end
