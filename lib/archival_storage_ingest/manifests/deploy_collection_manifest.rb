# frozen_string_literal: true

require 'archival_storage_ingest/ingest_utils/ingest_utils'
require 'archival_storage_ingest/manifests/manifests'
require 'archival_storage_ingest/manifests/manifest_of_manifests'
require 'fileutils'
require 'json'

module Manifests
  # collection manifest is old term for storage manifest
  # in the future, we may refactor reference to collection manifest to storage manifest
  class CollectionManifestDeployer
    attr_reader :file_identifier, :manifest_of_manifests, :manifest_validator, :sfs_prefix

    # initialize accepts these keys:
    # manifest_path, s3_manager
    # manifest_validator - uses default one in production, specify one for testing
    # sfs_prefix, java_path, tika_path - uses default values in production, specify them for testing
    #                                    these are used to initialize FileIdentifier
    # rubocop:disable Metrics/ParameterLists
    def initialize(manifests_path:, s3_manager:, wasabi_manager:, file_identifier:, sfs_prefix:,
                   manifest_validator: Manifests::ManifestValidator.new)
      @mom_path = manifests_path
      @manifest_of_manifests = Manifests::ManifestOfManifests.new(manifests_path)

      @s3_manager = s3_manager
      @wasabi_manager = wasabi_manager
      @file_identifier = file_identifier
      @manifest_validator = manifest_validator
      @sfs_prefix = sfs_prefix
    end
    # rubocop:enable Metrics/ParameterLists

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

      manifest_parameters.storage_manifest = manifest
      manifest
    end

    def populate_manifest_data(manifest_parameters:)
      if manifest_parameters.skip_data_addition
        manifest_parameters.storage_manifest
      else
        add_ingest_date(storage_manifest: manifest_parameters.storage_manifest,
                        ingest_manifest: manifest_parameters.ingest_manifest,
                        ingest_date: manifest_parameters.ingest_date)
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

    def describe_deployment(manifest_def:)
      mdef_hash = manifest_def.to_hash
      mdef_hash.keys.sort.each do |key|
        puts "#{key}: #{mdef_hash[key]}"
      end
    end

    def deploy_collection_manifest(manifest_def:, collection_manifest:, dest: nil)
      deploy_sfs(cm_path: collection_manifest, manifest_def: manifest_def)
      deploy_s3(cm_path: collection_manifest, manifest_def: manifest_def)
      deploy_wasabi(cm_path: collection_manifest, manifest_def: manifest_def)
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

    def deploy_wasabi(cm_path:, manifest_def:)
      @wasabi_manager.upload_file(manifest_def.s3_key, cm_path)
    end

    def deploy_asif(cm_path:, manifest_def:)
      @s3_manager.upload_asif_manifest(s3_key: manifest_def.s3_key, manifest_file: cm_path)
    end

    def deploy_manifest_definition(dest: nil)
      destination = manifest_of_manifests.save(dest: dest)

      puts "Manifest of manifests at #{destination} is updated.  Please commit the change."
    end
  end

  class MigrationCollectionManifestDeployer < CollectionManifestDeployer
    def prepare_collection_manifest(manifest_parameters:)
      manifest = super
      manifest.documentation = manifest_parameters.ingest_manifest.documentation
      manifest
    end

    # We want to preserve ingest date from ingest manifest
    def populate_manifest_data(manifest_parameters:)
      add_ingest_date(storage_manifest: manifest_parameters.storage_manifest,
                      ingest_manifest: manifest_parameters.ingest_manifest)
    end

    def add_ingest_date(storage_manifest:, ingest_manifest:)
      ingest_manifest.walk_packages do |package|
        cm_package = storage_manifest.get_package(package_id: package.package_id)
        package.walk_files do |file|
          cm_file = cm_package.find_file(filepath: file.filepath)
          cm_file.ingest_date = file.ingest_date
        end
      end

      storage_manifest
    end

    def deploy_collection_manifest(manifest_def:, collection_manifest:, dest: nil, dry_run: false)
      if dry_run
        File.foreach(collection_manifest) { |each_line| puts each_line }
      else
        deploy_sfs(cm_path: collection_manifest, manifest_def: manifest_def)
        deploy_s3(cm_path: collection_manifest, manifest_def: manifest_def)
        deploy_asif(cm_path: collection_manifest, manifest_def: manifest_def)
        deploy_manifest_definition(dest: dest)
      end
    end
  end

  # storage_manifest_path:, ingest_manifest_path:, sfs: nil, ingest_date: nil,
  # skip_data_addition: false
  class ManifestParameters
    attr_reader :storage_manifest_path, :ingest_manifest_path,
                :ingest_manifest, :sfs, :skip_data_addition, :ingest_date
    attr_accessor :storage_manifest

    def initialize(named_params)
      @storage_manifest_path = named_params.fetch(:storage_manifest_path)
      @storage_manifest = Manifests.read_manifest(filename: @storage_manifest_path)
      @ingest_manifest_path = resolve_ingest_manifest_path(named_params)
      @ingest_manifest = resolve_ingest_manifest(source: @ingest_manifest_path)
      @ingest_date = named_params.fetch(:ingest_date, nil)
      @sfs = named_params.fetch(:sfs, nil)
      @skip_data_addition = named_params.fetch(:skip_data_addition, false)
    end

    def resolve_ingest_manifest_path(named_params)
      named_params.fetch(:ingest_manifest_path)
    end

    def resolve_ingest_manifest(source:)
      Manifests.read_manifest(filename: source)
    end

    def depositor
      storage_manifest.depositor
    end

    def collection_id
      storage_manifest.collection_id
    end
  end
end
