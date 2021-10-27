# frozen_string_literal: true

require 'archival_storage_ingest/ingest_utils/ingest_utils'
require 'archival_storage_ingest/manifests/manifests'
require 'archival_storage_ingest/manifests/manifest_of_manifests'
require 'fileutils'
require 'json'
require 'open3'

module Manifests
  SFS_PREFIX = '/cul/data'

  # collection manifest is old term for storage manifest
  # in the future, we may refactor reference to collection manifest to storage manifest
  class CollectionManifestDeployer
    attr_reader :file_identifier, :manifest_of_manifests, :manifest_validator, :sfs_prefix

    # initialize accepts these keys:
    # manifest_path, s3_manager
    # manifest_validator - uses default one in production, specify one for testing
    # sfs_prefix, java_path, tika_path - uses default values in production, specify them for testing
    #                                    these are used to initialize FileIdentifier
    def initialize(manifests_path:, s3_manager:, file_identifier:, sfs_prefix:,
                   manifest_validator: Manifests::ManifestValidator.new)
      @mom_path = manifests_path
      @manifest_of_manifests = Manifests::ManifestOfManifests.new(manifests_path)

      @s3_manager = s3_manager
      @file_identifier = file_identifier
      @manifest_validator = manifest_validator
      @sfs_prefix = sfs_prefix
    end

    def prepare_manifest_definition(manifest_parameters:)
      prepare_collection_manifest(manifest_parameters: manifest_parameters)
      manifest_def = manifest_of_manifests.manifest_definition(depositor: manifest_parameters.depositor,
                                                               collection: manifest_parameters.collection_id)

      if manifest_def.nil?
        manifest_of_manifests.add_manifest_definition(storage_manifest_path: manifest_parameters.storage_manifest_path,
                                                      sfs: manifest_parameters.sfs)
      else
        manifest_def.sha1 = IngestUtils.calculate_checksum(filepath: manifest_parameters.storage_manifest_path)[0]
        manifest_def
      end
    end

    def prepare_collection_manifest(manifest_parameters:)
      manifest = populate_manifest_data(manifest_parameters: manifest_parameters)

      @manifest_validator.validate_storage_manifest(manifest: manifest)

      json_to_write = JSON.pretty_generate(manifest.to_json_storage_hash)
      File.open(manifest_parameters.storage_manifest_path, 'w') { |file| file.write(json_to_write) }

      manifest
    end

    def populate_manifest_data(manifest_parameters:)
      if manifest_parameters.skip_data_addition
        manifest_parameters.storage_manifest
      else
        smi = StorageManifestInitializer.new(file_identifier: file_identifier,
                                             identify_from_source: manifest_parameters.identify_from_source)
        smi.prepare_collection_manifest(collection_manifest: manifest_parameters.storage_manifest,
                                        ingest_manifest: manifest_parameters.ingest_manifest,
                                        ingest_date: manifest_parameters.ingest_date)
      end
    end

    def describe_deployment(manifest_def:)
      mdef_hash = manifest_def.to_hash
      mdef_hash.keys.sort.each do |key|
        puts "#{key}: #{mdef_hash[key]}"
      end
    end

    def deploy_collection_manifest(manifest_def:, collection_manifest:, dest: nil)
      deploy_sfs(cm_path: collection_manifest, manifest_def: manifest_def)
      deploy_s3(cm_path: collection_manifest, manifest_def: manifest_def)
      deploy_asif(cm_path: collection_manifest, manifest_def: manifest_def)
      deploy_manifest_definition(dest: dest)
    end

    def deploy_sfs(cm_path:, manifest_def:)
      manifest_def.sfs.each do |sfs|
        target = File.join(@sfs_prefix, sfs, manifest_def.depositor, manifest_def.collection, manifest_def.path)
        FileUtils.copy(cm_path, target)
      end
    end

    def deploy_s3(cm_path:, manifest_def:)
      @s3_manager.upload_file(manifest_def.s3_key, cm_path)
    end

    def deploy_asif(cm_path:, manifest_def:)
      @s3_manager.upload_asif_manifest(s3_key: manifest_def.s3_key, manifest_file: cm_path)
    end

    def deploy_manifest_definition(dest: nil)
      destination = manifest_of_manifests.save(dest: dest)

      puts "Manifest of manifests at #{destination} is updated.  Please commit the change."
    end
  end

  class StorageManifestInitializer
    attr_reader :file_identifier, :identify_from_source

    def initialize(file_identifier:, identify_from_source: true)
      @file_identifier = file_identifier
      @identify_from_source = identify_from_source
    end

    def prepare_collection_manifest(collection_manifest:, ingest_manifest:, ingest_date: nil)
      manifest = add_ingest_date(storage_manifest: collection_manifest, ingest_manifest: ingest_manifest,
                                 ingest_date: ingest_date)

      if identify_from_source
        identify_files_from_source(ingest_manifest: ingest_manifest, storage_manifest: manifest)
      else
        identify_files_from_storage(storage_manifest: manifest)
      end
    end

    def add_ingest_date(storage_manifest:, ingest_manifest:, ingest_date: nil)
      ingest_date = Time.new.strftime('%Y-%m-%d') if ingest_date.nil?
      ingest_manifest.walk_packages do |package|
        cm_package = storage_manifest.get_package(package_id: package.package_id)
        package.walk_files do |file|
          cm_file = cm_package.find_file(filepath: file.filepath)
          cm_file.ingest_date = ingest_date
        end
      end

      storage_manifest
    end

    # Running java process would result in initializing it for every run which appears to be wasteful.
    # There is a server mode available where putting the file gives us the result.
    # However, that mode will require transfer of all of the contents of the file locally via http for each run
    # and for big files (Africana has files bigger than 100G), it takes SIGNIFICANTLY longer than just
    # running it in app mode.
    # The app mode took about 2 seconds for 4M file and 2.6 seconds for 150G video file.
    # For comparison, the server mode took about .5 seconds for 4M file and A LOT LONGER for 150G video file.
    # I will use app mode with Open3 until a better solution emerges.
    #
    # identify_files_from_source is for ingest
    #   it will identify files referenced in the ingest manifest ONLY
    #   it will use the source data to determine media type
    #   this is all-cloud safe way to populate file id going forward
    # identify_files_from_storage is for retroactive file id population
    #   it will go through ALL files referenced in the storage manifest and determine location on SFS
    def identify_files_from_source(ingest_manifest:, storage_manifest:)
      ingest_manifest.walk_packages do |package|
        cm_package = storage_manifest.get_package(package_id: package.package_id)
        package.walk_files do |file|
          cm_file = cm_package.find_file(filepath: file.filepath)
          cm_file.media_type = file_identifier.identify_from_source(ingest_package: package, file: file)
          cm_file.tool_version = IDENTIFY_TOOL
        end
      end

      storage_manifest
    end

    def identify_files_from_storage(storage_manifest:)
      storage_manifest.walk_all_filepath do |file|
        file.media_type = file_identifier.identify_from_storage(manifest: storage_manifest, file: file)
        file.tool_version = Manifests::IDENTIFY_TOOL
      end

      storage_manifest
    end
  end

  # storage_manifest_path:, ingest_manifest_path:, sfs: nil, ingest_date: nil,
  #                    skip_data_addition: false, identify_from_source: true
  class ManifestParameters
    attr_reader :storage_manifest_path, :ingest_manifest_path, :storage_manifest, :ingest_manifest, :sfs,
                :skip_data_addition, :identify_from_source, :ingest_date

    def initialize(named_params)
      @storage_manifest_path = named_params.fetch(:storage_manifest_path)
      @storage_manifest = Manifests.read_manifest(filename: @storage_manifest_path)
      @ingest_manifest_path = named_params.fetch(:ingest_manifest_path)
      @ingest_manifest = Manifests.read_manifest(filename: @ingest_manifest_path)
      @ingest_date = named_params.fetch(:ingest_date, nil)
      @sfs = named_params.fetch(:sfs, nil)
      @skip_data_addition = named_params.fetch(:skip_data_addition, false)
      @identify_from_source = named_params.fetch(:identify_from_source, true)
    end

    def depositor
      storage_manifest.depositor
    end

    def collection_id
      storage_manifest.collection_id
    end
  end
end
