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

    def initialize(manifest:, csv:)
      @manifest = Manifests.read_manifest(filename: manifest)
      init_files(csv)
      @error = []
    end

    def init_files(csv)
      @packages = {}
      CSV.foreach(csv, headers: true) do |row|
        package_id = row.fetch(PACKAGE_ID)
        @packages[package_id] = [] if @packages[package_id].nil?
        @packages[package_id] << { package_id:, filepath: row.fetch(FILEPATH),
                                   fixity: row.fetch(FIXITY), size: row.fetch(SIZE).to_i }
      end
    end

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
