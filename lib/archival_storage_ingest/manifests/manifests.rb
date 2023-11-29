# frozen_string_literal: true

require 'archival_storage_ingest/exception/ingest_exception'
require 'archival_storage_ingest/ingest_utils/ingest_utils'
require 'json'
require 'json_schemer'
require 'open3'
require 'pathname'

module Manifests
  BLANK_JSON_TEXT = '{"locations":[],"packages":[]}'
  IDENTIFY_TOOL = 'Apache Tika 2.1.0'
  MANIFEST_TYPE_INGEST = 'ingest_manifest'
  MANIFEST_TYPE_STORAGE = 'storage_manifest'
  MANIFEST_TYPE_FIXITY = 'fixity_manifest'
  DEFAULT_SFS_PREFIX = '/cul/data'

  def self.read_manifest(filename:)
    json_io = File.open(filename)
    read_manifest_io(json_io:)
  end

  def self.read_manifest_io(json_io:)
    json_text = json_io.read
    Manifests::Manifest.new(json_text:)
  end

  def self.diff_hash(flattened_a, flattened_b)
    left = flattened_a.to_a
    right = flattened_b.to_a
    IngestUtils.compact_blank({
                                ingest: (left - right).to_h,
                                other: (right - left).to_h
                              })
  end

  def self.collection_manifest_filename(depositor:, collection:)
    dep = depositor.sub('/', '_')
    col = collection.sub('/', '_')
    "_EM_#{dep}_#{col}.json"
  end

  class Manifest # rubocop:disable Metrics/ClassLength
    attr_accessor :collection_id, :depositor, :steward, :locations, :packages, :documentation

    # initialize from the json string
    def initialize(json_text: BLANK_JSON_TEXT) # rubocop:disable Metrics/MethodLength
      json_hash = JSON.parse(json_text, symbolize_names: true)
      @collection_id = json_hash[:collection_id]
      @depositor = json_hash[:depositor]
      @documentation = json_hash[:documentation]
      @steward = json_hash[:steward]
      @locations = json_hash[:locations]
      @locations = [] if @locations.nil?
      @packages = if json_hash[:packages]
                    json_hash[:packages].map do |package|
                      Manifests::Package.new(package:)
                    end
                  else
                    []
                  end
    end

    def add_package(package:)
      package_id = package.package_id
      if get_package(package_id:)
        raise IngestException,
              "Package id #{package_id} already exists and can't be added."
      end

      packages << package
    end

    def number_packages
      @packages.length
    end

    def add_filepath(package_id:, filepath:, sha1:, size:)
      get_package(package_id:).add_file_entry(filepath:, sha1:, size:)
    end

    # not sure how/when we would use this function, yet
    def update_filepath(_package_id:, _filepath:, _sha1:, _size:); end

    def get_package(package_id:)
      packages.find { |package| package.package_id == package_id }
    end

    def walk_packages(&)
      packages.each(&)
    end

    def walk_filepath(package_id:, &block)
      get_package(package_id:).walk_files(&block)
    end

    def walk_all_filepath(&)
      walk_packages do |package|
        package.walk_files(&)
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
      IngestUtils.compact_blank({
                                  depositor:, collection_id:,
                                  steward:, documentation:,
                                  number_packages:,
                                  packages: packages.map(&:to_json_ingest)
                                })
    end

    def to_json_ingest
      to_json_ingest_hash.to_json
    end

    def to_json_storage_hash
      IngestUtils.compact_blank({
                                  depositor:, collection_id:,
                                  steward:, documentation:,
                                  locations:, number_packages:,
                                  packages: packages.map(&:to_json_hash_storage)
                                })
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
    attr_accessor :collection_manifest_filename, :fixity_mode

    def initialize(cm_filename:, fixity_mode: true)
      @collection_manifest_filename = cm_filename
      @fixity_mode = fixity_mode
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
        diffs[:ingest] << key unless _diff(value, m2_flat[key])
      end
      m2_flat.each do |key, value|
        diffs[:other] << key unless _diff(value, m1_flat[key])
      end
      diffs
    end

    def _diff(file_a, file_b)
      if fixity_mode
        file_a.fixity_equals(file_b)
      else
        file_a == file_b
      end
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
      @files = package[:files] ? package[:files].map { |file| Manifests::FileEntry.new(file:) } : []
      @number_files = package[:number_files] || files.length
    end

    def add_file_entry(filepath:, sha1:, size:, md5: nil)
      file_hash = { filepath:, sha1:, md5:, size: }
      add_file(file: FileEntry.new(file: file_hash))
    end

    def add_file(file:)
      files << file
      @number_files += 1
      file
    end

    def walk_files(&)
      files.each(&)
    end

    def find_file(filepath:)
      index = files.index { |file| file.filepath == filepath }
      return files[index] unless index.nil?

      nil
    end

    def update_file_entry(filepath:, sha1:, size:, md5: nil)
      file_hash = { filepath:, sha1:, md5:, size: }
      update_file(file: FileEntry.new(file: file_hash))
    end

    def update_file(file:)
      file_to_update = find_file(filepath: file.filepath)
      if file_to_update.nil?
        file_to_update = add_file(file:)
      else
        file_to_update.sha1 = file.sha1
        file_to_update.size = file.size
      end
      file_to_update
    end

    def ==(other)
      return false unless other.instance_of?(Package)

      return false unless source_path == other.source_path

      return false unless bibid == other.bibid

      return false unless local_id == other.local_id

      return false unless number_files == other.number_files

      return false unless files == other.files

      true
    end

    def to_json_hash_storage
      IngestUtils.compact_blank({
                                  package_id:,
                                  bibid:,
                                  local_id:,
                                  number_files:,
                                  files: files.map(&:to_json_hash_storage)
                                })
    end

    def to_json_ingest
      IngestUtils.compact_blank({
                                  package_id:,
                                  source_path:,
                                  bibid:,
                                  local_id:,
                                  number_files:,
                                  files: files.map(&:to_json_hash)
                                })
    end

    def to_json_fixity
      {
        package_id:,
        files: files.map(&:to_fixity_json_hash)
      }
    end
  end

  class FileEntry
    attr_accessor :filepath, :sha1, :md5, :size, :ingest_date, :tool_version, :media_type

    def initialize(file:)
      @filepath = file[:filepath]
      @sha1 = file[:sha1]
      @md5 = file[:md5]
      @size = file[:size]
      @ingest_date = file[:ingest_date]
      @tool_version = IDENTIFY_TOOL # fix it to a specific version of Tika
      @media_type = file[:media_type].nil? ? '' : file[:media_type]
    end

    def copy(other)
      return unless filepath == other.filepath

      @sha1 = other.sha1
      @md5 = other.md5
      @size = other.size
      @ingest_date = other.ingest_date
      @tool_version = other.tool_version
      @media_type = other.media_type
    end

    def list_checksum_info
      IngestUtils.compact_blank({
                                  sha1:,
                                  md5:
                                })
    end

    # All assets in archival storage must have SHA1 checksum.
    # We will ignore the MD5 value at all times during fixity checks.
    def ==(other)
      return false unless fixity_equals(other)

      return false unless ingest_date == other.ingest_date

      return false unless tool_version == other.tool_version &&
                          media_type == other.media_type

      true
    end

    def fixity_equals(other)
      return false unless other.instance_of?(FileEntry)

      # pp "#{filepath} : #{other.filepath}" unless filepath == other.filepath
      return false unless filepath == other.filepath

      # pp "#{sha1} : #{other.sha1}" unless sha1 == other.sha1
      return false unless sha1 == other.sha1

      # pp "#{size} : #{other.size}" unless size == other.size
      return false unless size == other.size

      # This function checks only filepath, sha1, and size
      # All other attributes of file are ignored

      true
    end

    def to_json_hash_storage
      IngestUtils.compact_blank({
                                  filepath:,
                                  sha1:,
                                  md5:,
                                  size:,
                                  ingest_date:,
                                  tool_version:,
                                  media_type:
                                })
    end

    def to_json_hash
      IngestUtils.compact_blank({
                                  filepath:,
                                  sha1:,
                                  md5:,
                                  size:,
                                  tool_version:,
                                  media_type:
                                })
    end

    def to_fixity_json_hash
      IngestUtils.compact_blank({
                                  filepath:,
                                  sha1:,
                                  size:
                                })
    end
  end

  class ManifestValidator
    DEFAULT_INGEST_SCHEMA = '/cul/app/cular-metadata/manifest_schema_ingest.json'
    DEFAULT_STORAGE_SCHEMA = '/cul/app/cular-metadata/manifest_schema_storage.json'
    attr_reader :ingest_schema, :storage_schema

    def initialize(ingest_schema: DEFAULT_INGEST_SCHEMA, storage_schema: DEFAULT_STORAGE_SCHEMA)
      @ingest_schema = JSONSchemer.schema(Pathname.new(ingest_schema))
      @storage_schema = JSONSchemer.schema(Pathname.new(storage_schema))
    end

    def _validate_manifest(schema:, data_symbol_hash:)
      # we need to generate/parse to convert symbol to quotes as this schema doesn't work with symbols
      json = JSON.generate(data_symbol_hash)

      json_data_hash = JSON.parse(json)
      errors = schema.validate(json_data_hash).to_a
      raise IngestException, "Failed to validate manifest: #{errors}" unless errors.empty?

      true
    end

    def validate_ingest_manifest(manifest:)
      _validate_manifest(schema: ingest_schema, data_symbol_hash: manifest.to_json_ingest_hash)
    end

    def validate_storage_manifest(manifest:)
      _validate_manifest(schema: storage_schema, data_symbol_hash: manifest.to_json_storage_hash)
    end
  end

  class FileIdentifier
    attr_reader :java_path, :sfs_prefix, :tika_path, :identify_tool

    DEFAULT_JAVA_PATH = 'java'
    DEFAULT_TIKA_PATH = '/cul/app/tika/tika-app-2.1.0.jar'
    SFS_TRIM_PREFIX = 'smb://files.cornell.edu/lib/'

    def initialize(sfs_prefix: nil, java_path: DEFAULT_JAVA_PATH, tika_path: DEFAULT_TIKA_PATH,
                   identify_tool: IDENTIFY_TOOL)
      @java_path = java_path
      @tika_path = tika_path
      @sfs_prefix = sfs_prefix
      @identify_tool = identify_tool
    end

    def resolve_filepath(manifest:, file:)
      raise IngestException, 'SFS prefix not specified' if sfs_prefix.nil?

      location = nil
      manifest.locations.each do |loc|
        next if loc.start_with?('s3')

        relative_path = IngestUtils.relative_path(loc, SFS_TRIM_PREFIX)
        path = File.join(sfs_prefix, relative_path, file.filepath)
        location = path if File.exist?(path)
      end

      location
    end

    def identify_from_source(ingest_package:, file:)
      abs_path = File.join(ingest_package.source_path, file.filepath)
      raise IngestException, "Failed to identify file #{file.filepath}" unless File.exist?(abs_path)

      _identify(abs_path:)
    end

    def identify_from_storage(manifest:, file:)
      abs_path = resolve_filepath(manifest:, file:)
      # resolve_filepath only returns valid abs_path if file exists
      raise IngestException, "Failed to identify file #{file.filepath}" if abs_path.nil?

      _identify(abs_path:)
    end

    def _identify(abs_path:)
      stdout, _stderr, status = Open3.capture3(java_path, '-jar', tika_path, '-x', '-d', abs_path)
      return stdout.chomp if status.success?

      'application/octet-stream'
    end
  end
end
