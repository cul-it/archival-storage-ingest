# frozen_string_literal: true

require 'json'

module Manifests
  BLANK_JSON_TEXT = '{"locations":[],"packages":[]}'
  MANIFEST_TYPE_INGEST = 'ingest_manifest'
  MANIFEST_TYPE_STORAGE = 'storage_manifest'
  MANIFEST_TYPE_FIXITY = 'fixity_manifest'

  def self.read_manifest(filename:)
    json_io = File.open(filename)
    read_manifest_io(json_io)
  end

  def self.read_manifest_io(json_io:)
    json_text = json_io.read
    Manifests::Manifest.new(json_text: json_text)
  end


  class Manifest
    attr_accessor :collection_id, :depositor, :steward, :rights, :locations, :number_packages, :packages

    # initialize from the json string
    def initialize(json_text: BLANK_JSON_TEXT)
      json_hash = JSON.parse(json_text, symbolize_names: true)
      @collection_id = json_hash[:collection_id]
      @depositor = json_hash[:depositor]
      @steward = json_hash[:steward]
      @rights = json_hash[:rights]
      @locations = json_hash[:locations]
      @packages = json_hash[:packages] ? json_hash[:packages].map { |package| Manifests::Package.new(package: package) } : []
      @number_packages = json_hash[:number_packages] || @packages.length
    end

    def add_package(package:)
      package_id = package.package_id
      raise IngestException, "Package id #{package_id} already exists and can't be added." if get_package(package_id: package_id)

      packages << package
    end

    def add_filepath(package_id:, filepath:, sha1:, size:)
      get_package(package_id: package_id).add_file_entry(filepath: filepath, sha1: sha1, size: size)
    end

    # not sure how/when we would use this function, yet
    def update_filepath(_package_id:, _filepath:, _sha1:, _size:); end

    def get_package(package_id:)
      packages.find { |package| package.package_id == package_id }
    end

    def walk_packages
      packages.each do |package|
        yield(package)
      end
    end

    def walk_filepath(package_id:)
      get_package(package_id: package_id).walk_files do |file|
        yield(file)
      end
    end

    def walk_all_filepath
      walk_packages do |package|
        package.walk_files do |file|
          yield(file)
        end
      end
    end

    def compare_manifest(_other_manifest:); end

    # json_type is either ingest or storage
    # Details of the differences can be found at:
    # https://github.com/cul-it/cular-metadata/
    def to_json(json_type: MANIFEST_TYPE_STORAGE)
      return to_json_fixity if json_type == MANIFEST_TYPE_FIXITY

      return to_json_ingest if json_type == MANIFEST_TYPE_INGEST

      to_json_storage
    end

    def to_json_ingest
      {
        collection_id: collection_id,
        depositor: depositor,
        steward: steward,
        rights: rights,
        locations: locations,
        number_packages: number_packages,
        packages: packages.map(&:to_json_ingest)
      }.compact.to_json
    end

    def to_json_storage
      {
        collection_id: collection_id,
        depositor: depositor,
        steward: steward,
        rights: rights,
        locations: locations,
        number_packages: number_packages,
        packages: packages.map(&:to_json_storage)
      }.compact.to_json
    end

    def to_json_fixity
      {
        packages: packages.map(&:to_json_fixity)
      }.to_json
    end
  end

  # initializes a package from JSON snippet
  # It currently lacks validating whether required attributes are missing.
  class Package
    attr_accessor :package_id, :source_path, :bibid, :local_id, :number_files, :files
    def initialize(package:)
      @package_id = package[:package_id]
      @source_path = package[:source_path]
      @bibid = package[:bibid]
      @local_id = package[:local_id]
      @files = package[:files] ? package[:files].map { |file| Manifests::FileEntry.new(file: file) } : []
      @number_files = package[:number_files] || files.length
    end

    def add_file_entry(filepath:, sha1:, size:, md5: nil)
      file = { filepath: filepath, sha1: sha1, md5: md5, size: size }
      files << FileEntry.new(file: file)
      @number_files += 1
    end

    def walk_files
      files.each do |file|
        yield(file)
      end
    end

    def to_json_hash_storage
      {
        package_id: package_id,
        bibid: bibid,
        local_id: local_id,
        number_files: number_files,
        files: files.map(&:to_json_hash)
      }.compact
    end

    def to_json_ingest
      {
        package_id: package_id,
        source_path: source_path,
        bibid: bibid,
        local_id: local_id,
        number_files: number_files,
        files: files.map(&:to_json_hash)
      }.compact
    end

    def to_json_fixity
      {
        package_id: package_id,
        files: files.map(&:to_json_hash)
      }
    end
  end

  class FileEntry
    attr_accessor :filepath, :sha1, :md5, :size
    def initialize(file:)
      @filepath = file[:filepath]
      @sha1 = file[:sha1]
      @md5 = file[:md5]
      @size = file[:size]
    end

    def ==(other)
      return false unless other.instance_of?(FileEntry)

      return false unless filepath == other.filepath

      return false unless sha1 == other.sha1

      return false unless md5 == other.md5

      return false unless size == other.size

      true
    end

    def to_json_hash
      {
        filepath: filepath,
        sha1: sha1,
        md5: md5,
        size: size
      }.compact
    end
  end

end
