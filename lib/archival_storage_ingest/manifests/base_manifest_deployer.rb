#!/usr/bin/env ruby
# frozen_string_literal: true

require 'archival_storage_ingest/manifests/manifests'
require 'archival_storage_ingest/manifests/manifest_of_manifests'
require 'misc/archive_size'
require 'archival_storage_ingest/s3/s3_manager'
require 'archival_storage_ingest/wasabi/wasabi_manager'

class BaseManifestDeployer # rubocop:disable Metrics/ClassLength
  attr_writer :storage_schema, :ingest_schema, :java_path, :tika_path, :file_identifier, :manifest_of_manifests,
              :s3_bucket, :asif_bucket, :asif_archive_size_bucket, :s3_manager, :sfs_prefix,
              :manifest_validator, :skip_data_addition, :manifest_deployer, :archives, :archive_size

  def storage_schema
    @storage_schema ||= _storage_schema
  end

  def _storage_schema
    ENV['asi_storage_schema'] || Manifests::ManifestValidator::DEFAULT_STORAGE_SCHEMA
  end

  def ingest_schema
    @ingest_schema ||= _ingest_schema
  end

  def _ingest_schema
    ENV['asi_ingest_schema'] || Manifests::ManifestValidator::DEFAULT_INGEST_SCHEMA
  end

  def java_path
    @java_path ||= _java_path
  end

  def _java_path
    ENV['asi_java_path'] || Manifests::FileIdentifier::DEFAULT_JAVA_PATH
  end

  def tika_path
    @tika_path ||= _tika_path
  end

  def _tika_path
    ENV['asi_tika_path'] || Manifests::FileIdentifier::DEFAULT_TIKA_PATH
  end

  def file_identifier
    @file_identifier ||= _file_identifier
  end

  def _file_identifier
    Manifests::FileIdentifier.new(java_path:, tika_path:,
                                  sfs_prefix:)
  end

  def manifest_of_manifests
    @manifest_of_manifests ||= _manifest_of_manifests
  end

  def _manifest_of_manifests
    default = Manifests::ManifestOfManifests::DEFAULT_MANIFEST_OF_MANIFESTS
    ENV['asi_manifest_of_manifest'] || default
  end

  def s3_bucket
    @s3_bucket ||= _s3_bucket
  end

  def _s3_bucket
    ENV['asi_develop'] || ENV['asi_deploy_manifest_develop'] ? 's3-cular-dev' : 's3-cular'
  end

  def wasabi_bucket
    @wasabi_bucket ||= _wasabi_bucket
  end

  def _wasabi_bucket
    ENV['asi_develop'] || ENV['asi_deploy_manifest_develop'] ? 'wasabi-cular-dev' : 'wasabi-cular'
  end

  def asif_bucket
    @asif_bucket ||= _asif_bucket
  end

  def _asif_bucket
    if ENV['asi_develop'] || ENV['asi_deploy_manifest_develop']
      's3-cular-asif-manifests-dev'
    else
      's3-cular-asif-manifests-prod'
    end
  end

  def asif_archive_size_bucket
    @asif_archive_size_bucket ||= _asif_archive_size_bucket
  end

  def _asif_archive_size_bucket
    if ENV['asi_develop'] || ENV['asi_deploy_manifest_develop']
      's3-cular-asif-archive-size-dev'
    else
      's3-cular-asif-archive-size-prod'
    end
  end

  def s3_manager
    @s3_manager ||= _s3_manager
  end

  def _s3_manager
    S3Manager.new(s3_bucket, asif_bucket, asif_archive_size_bucket)
  end

  def wasabi_manager
    @wasabi_manager ||= _wasabi_manager
  end

  def _wasabi_manager
    WasabiManager.new(wasabi_bucket)
  end

  def sfs_prefix
    @sfs_prefix ||= _sfs_prefix
  end

  def _sfs_prefix
    if ENV['asi_develop'] || ENV['asi_deploy_manifest_develop']
      '/cul/app/archival_storage_ingest/test/deploy'
    else
      Manifests::DEFAULT_SFS_PREFIX
    end
  end

  def manifest_validator
    @manifest_validator ||= _manifest_validator
  end

  def _manifest_validator
    Manifests::ManifestValidator.new(storage_schema:, ingest_schema:)
  end

  def skip_data_addition
    @skip_data_addition ||= _skip_data_addition
  end

  def _skip_data_addition
    !(skip_data_addition.nil? || skip_data_addition != 'true')
  end

  def manifest_deployer
    @manifest_deployer ||= _manifest_deployer
  end

  def _manifest_deployer; end

  # def manifest_parameters
  #   @manifest_parameters ||= _manifest_parameters
  # end
  # def _manifest_parameters; end

  def archives
    @archives ||= _archives
  end

  def _archives
    [
      { archive: '/cul/data/archival01' },
      { archive: '/cul/data/archival02' },
      { archive: '/cul/data/archival03' },
      { archive: '/cul/data/archival04' },
      { archive: '/cul/data/archival05' },
      { archive: '/cul/data/archival06' },
      { archive: '/cul/data/archival07' }
    ]
  end

  def archive_size
    @archive_size ||= _archive_size
  end

  def _archive_size
    ArchiveSize::ArchiveSize.new(archives:, s3_manager:)
  end

  def deploy_manifest(manifest_parameters:)
    # This step will finalize storage manifest object and file pointed by the manifest parameters.
    manifest_deployer.prepare_collection_manifest(manifest_parameters:)
    manifest_definition = manifest_deployer.prepare_manifest_definition(manifest_parameters:)

    describe_and_confirm_deployment(manifest_deployer:, manifest_definition:)

    manifest_deployer.deploy_collection_manifest(manifest_def: manifest_definition,
                                                 collection_manifest: manifest_parameters.storage_manifest_path)
    archive_size.deploy_asif_archive_size
  end

  def describe_and_confirm_deployment(manifest_deployer:, manifest_definition:)
    puts 'Deployment Summary'
    puts "S3 bucket: #{s3_bucket}"
    manifest_deployer.describe_deployment(manifest_def: manifest_definition)

    puts 'Proceed with deployment? (Y/N)'
    unless 'y'.casecmp(gets.chomp).zero? # rubocop:disable Style/GuardClause
      puts 'Deployment terminated by user input.'
      exit
    end
  end
end
