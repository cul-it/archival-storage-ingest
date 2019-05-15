# frozen_string_literal: true

require 'json'

module Manifests
  def self.read_manifest(filename:)
    json_io = File.open(filename)
    json_text = json_io.read
    Manifests::Manifest.new(json_text: json_text)
  end

  class Manifest
    attr :collection_id, :depositor, :steward, :rights,
         :locations, :number_packages, :packages

    # create clean slate manifest
    def initialize

    end

    # initialize from the json string
    def initialize(json_text:)
      json_hash = JSON.parse(json_text)
      collection_id = json_hash['collection_id']
      depositor = json_hash['depositor']
      steward = json_hash['steward']
      rights = json_hash['rights']
      locations = json_hash['locations']
      number_packages = json_hash['number_packages'] || json_hash['packages'].length
      packages = json_hash['packages'].map { |package| Manifests::Package.new(package: package) }
    end

    def add_file(package_id:, filepath:, sha1:, size:)
      # files[filepath] = { sha1: sha1, size: size }
      # @number_files += 1
    end

    def update_filepath(package_id:, filepath:, sha1:, size:)

    end

    def walk_packages
      # files.each do |filepath, sha1|
      #   yield(filepath, sha1)
      # end
    end

    def walk_filepath(package_id:)

    end

    def compare_manifest(other_manifest:)

    end

    # json_type is either ingest or storage
    # Details of the differences can be found at:
    # https://github.com/cul-it/cular-metadata/
    def to_json(json_type:)

    end
  end

  # initializes a package from JSON snippet
  class Package
    attr :package_id, :source_path, :bibid, :local_id, :number_files, :files
    def initialize(package:)
      package_id = package['package_id']
      source_path = package['source_path']
      bibid = package['bibid']
      local_id = package['local_id']
      number_files = package['number_files'] || package['files'].length
      files = package['files'].map { |file| Manifests::FileEntry.new(file: file) }
    end
  end

  class FileEntry
    attr_reader :filepath, :sha1, :md5, :size
    def initialize(file:)
      @filepath = file['filepath']
      @sha1 = file['sha1']
      @md5 = file['md5']
      @size = file['size']
    end
  end
end
