# frozen_string_literal: true

require 'json'

module Manifests
  BLANK_JSON_TEXT = '{"locations":[],"packages":[]}'
  MANIFEST_TYPE_INGEST = 'ingest_manifest'
  MANIFEST_TYPE_STORAGE = 'storage_manifest'
  MANIFEST_TYPE_FIXITY = 'fixity_manifest'

  def self.read_manifest(filename:)
    json_io = File.open(filename)
    read_manifest_io(json_io: json_io)
  end

  def self.read_manifest_io(json_io:)
    json_text = json_io.read
    Manifests::Manifest.new(json_text: json_text)
  end

  def self.diff_hash(flattened_a, flattened_b)
    left = flattened_a.to_a
    right = flattened_b.to_a
    {
      ingest: (left - right).to_h,
      other: (right - left).to_h
    }.compact
  end

  class Manifest
    attr_accessor :collection_id, :depositor, :steward, :locations, :packages, :documentation

    # initialize from the json string
    def initialize(json_text: BLANK_JSON_TEXT)
      json_hash = JSON.parse(json_text, symbolize_names: true)
      @collection_id = json_hash[:collection_id]
      @depositor = json_hash[:depositor]
      @documentation = json_hash[:documentation]
      @steward = json_hash[:steward]
      @locations = json_hash[:locations]
      @packages = json_hash[:packages] ? json_hash[:packages].map { |package| Manifests::Package.new(package: package) } : []
    end

    def add_package(package:)
      package_id = package.package_id
      raise IngestException, "Package id #{package_id} already exists and can't be added." if get_package(package_id: package_id)

      packages << package
    end

    def number_packages
      @packages.length
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

    def flattened
      all_files = {}
      walk_all_filepath do |filepath|
        filepath.md5 = nil
        all_files[filepath.filepath] = filepath
      end
      all_files
    end

    def diff(other_manifest)
      me_flattened = {}
      flattened.each { |k, v| me_flattened[k] = v.to_json_hash }
      other_flattened = {}
      other_manifest.flattened.each { |k, v| other_flattened[k] = v.to_json_hash }

      Manifests.diff_hash(me_flattened, other_flattened)
    end

    def fixity_diff(other_manifest)
      me_flattened = {}
      flattened.each { |k, v| me_flattened[k] = v.to_fixity_json_hash }
      other_flattened = {}
      other_manifest.flattened.each { |k, v| other_flattened[k] = v.to_fixity_json_hash }

      Manifests.diff_hash(me_flattened, other_flattened)
    end

    # json_type is either ingest or storage
    # Details of the differences can be found at:
    # https://github.com/cul-it/cular-metadata/
    def to_json(json_type: MANIFEST_TYPE_STORAGE)
      return to_json_fixity if json_type == MANIFEST_TYPE_FIXITY

      return to_json_ingest if json_type == MANIFEST_TYPE_INGEST

      to_json_storage
    end

    def to_json_ingest_hash
      {
        depositor: depositor, collection_id: collection_id,
        steward: steward, locations: locations,
        number_packages: number_packages,
        packages: packages.map(&:to_json_ingest)
      }.compact
    end

    def to_json_ingest
      to_json_ingest_hash.to_json
    end

    def to_json_storage_hash
      {
        depositor: depositor, collection_id: collection_id,
        steward: steward, documentation: documentation,
        locations: locations, number_packages: number_packages,
        packages: packages.map(&:to_json_hash_storage)
      }.compact
    end

    def to_json_storage
      to_json_storage_hash.to_json
    end

    def to_json_fixity_hash
      { packages: packages.map(&:to_json_fixity) }
    end

    def to_json_fixity
      to_json_fixity_hash.to_json
    end
  end

  class ManifestComparator
    attr_accessor :collection_manifest_filename
    def initialize(cm_filename:)
      @collection_manifest_filename = cm_filename
    end

    def fixity_diff(ingest:, fixity:)
      ingest_f = flatten_and_remove_cm(manifest: ingest)
      fixity_f = flatten_and_remove_cm(manifest: fixity)
      diffs = diff(m1_flat: ingest_f, m2_flat: fixity_f)
      status = (diffs[:ingest].count + diffs[:other].count).zero?
      [status, diffs]
    end

    def flatten_and_remove_cm(manifest:)
      flattened = manifest.flattened
      flattened.delete(collection_manifest_filename) if flattened[collection_manifest_filename]
      flattened
    end

    def diff(m1_flat:, m2_flat:)
      diffs = { ingest: [], other: [] }
      m1_flat.each do |key, value|
        diffs[:ingest] << key unless value == m2_flat[key]
      end
      m2_flat.each do |key, value|
        diffs[:other] << key unless value == m1_flat[key]
      end
      diffs
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
      file_hash = { filepath: filepath, sha1: sha1, md5: md5, size: size }
      add_file(file: FileEntry.new(file: file_hash))
    end

    def add_file(file:)
      files << file
      @number_files += 1
      file
    end

    def walk_files
      files.each do |file|
        yield(file)
      end
    end

    def find_file(filepath:)
      index = files.index { |file| file.filepath == filepath }
      return files[index] unless index.nil?

      nil
    end

    def update_file_entry(filepath:, sha1:, size:, md5: nil)
      file_hash = { filepath: filepath, sha1: sha1, md5: md5, size: size }
      update_file(file: FileEntry.new(file: file_hash))
    end

    def update_file(file:)
      file_to_update = find_file(filepath: file.filepath)
      if file_to_update.nil?
        file_to_update = add_file(file: file)
      else
        file_to_update.sha1 = file.sha1
        file_to_update.size = file.size
      end
      file_to_update
    end

    def ==(other) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
      return false unless other.instance_of?(Package)

      return false unless source_path == other.source_path

      return false unless bibid == other.bibid

      return false unless local_id == other.local_id

      return false unless number_files == other.number_files

      return false unless files == other.files

      true
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

    def copy(other)
      return unless filepath == other.filepath

      @sha1 = other.sha1
      @md5 = other.md5
      @size = other.size
    end

    # All assets in archival storage must have SHA1 checksum.
    # We will ignore the MD5 value at all times during fixity checks.
    def ==(other)
      return false unless other.instance_of?(FileEntry)

      # pp "#{filepath} : #{other.filepath}" unless filepath == other.filepath
      return false unless filepath == other.filepath

      # pp "#{sha1} : #{other.sha1}" unless sha1 == other.sha1
      return false unless sha1 == other.sha1

      # pp "#{size} : #{other.size}" unless size == other.size
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

    def to_fixity_json_hash
      {
        filepath: filepath,
        sha1: sha1,
        size: size
      }.compact
    end
  end
end
