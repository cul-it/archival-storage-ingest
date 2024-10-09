# frozen_string_literal: true

require 'archival_storage_ingest/exception/ingest_exception'
require 'archival_storage_ingest/ingest_utils/ingest_params'
require 'archival_storage_ingest/manifests/manifests'
require 'archival_storage_ingest/manifests/manifest_merger'
require 'archival_storage_ingest/manifests/manifest_missing_attribute_populator'
require 'archival_storage_ingest/manifests/manifest_to_filesystem_comparator'
require 'archival_storage_ingest/manifests/manifest_checker'
require 'archival_storage_ingest/manifests/overwrite_checker'
require 'archival_storage_ingest/messages/ingest_message'
require 'archival_storage_ingest/preingest/base_env_initializer'
require 'fileutils'
require 'json'
require 'yaml'

module Preingest
  class IngestEnvInitializer < BaseEnvInitializer # rubocop:disable Metrics/ClassLength
    attr_reader :file_identifier, :manifest_validator, :wasabi_manager, :overwrite_checker

    def initialize(ingest_root:, manifest_validator:, file_identifier:, wasabi_manager:, overwrite_checker:)
      super(ingest_root:)

      @file_identifier = file_identifier
      @manifest_validator = manifest_validator
      @wasabi_manager = wasabi_manager
      @overwrite_checker = overwrite_checker
    end

    # We need to run initialize_env first to populate depositor/collection from ingest manifest
    # and compare it to the provided values.
    # def initialize_ingest_env(named_params)
    #   initialize_env(named_params)

    #   unless depositor == named_params.fetch(:depositor) &&
    #          collection_id == named_params.fetch(:collection_id)
    #     msg = "Depositor/Collection mismatch!\n  " \
    #           "Given values: #{named_params.fetch(:depositor)}/#{named_params.fetch(:collection_id)}  " \
    #           "Manifest values: #{depositor}/#{collection_id}"
    #     raise IngestException, msg
    #   end
    # end

    # takes filepath of ingest_params
    def initialize_ingest_env(ingest_params:)
      initialize_ingest_env_from_params_obj(ingest_params: IngestUtils::IngestParams.new(ingest_params))
    end

    # takes IngestUtils::IngestParams object
    def initialize_ingest_env_from_params_obj(ingest_params:)
      initialize_env_from_params_obj(ingest_params:)

      return if depositor == ingest_params.depositor && collection_id == ingest_params.collection

      msg = "Depositor/Collection mismatch!\n  " \
            "Given values: #{ingest_params.depositor}/#{ingest_params.collection_id}  " \
            "Manifest values: #{@depositor}/#{@collection_id}"
      raise IngestException, msg
    end

    # Add data integrity check after copying ingest manifest to correct place
    def _initialize_ingest_manifest
      im_path = super

      manifest = _resolve_source_path(ingest_manifest_path: im_path)
      manifest = _populate_missing_attribute(ingest_manifest: manifest, write_target: im_path)
      raise IngestException, 'Asset mismatch' unless _compare_asset_existence(ingest_manifest: manifest)

      other_checksum_checker = Manifests::ManifestNonDefaultChecksumChecker.new
      other_checksum_checker.check_non_default_checksums(ingest_manifest: manifest)
      @manifest_validator.validate_ingest_manifest(manifest:)

      size_checker = Manifests::ManifestFilesizeChecker.new
      @total_size, @size_mismatch = size_checker.check_filesize(manifest:)

      im_path
    end

    def _resolve_source_path(ingest_manifest_path:)
      manifest = Manifests.read_manifest(filename: ingest_manifest_path)
      manifest.walk_packages do |package|
        package.source_path = ingest_params.asset_source
      end
      if ingest_params.doc_source != IngestUtils::IngestParams::SOURCE_NOT_APPLICABLE
        manifest = _setup_doc_source(ingest_manifest: manifest)
      end
      manifest
    end

    def _setup_doc_source(ingest_manifest:)
      doc_package_id = ingest_manifest.documentation
      doc_package = ingest_manifest.get_package(package_id: doc_package_id)
      doc_source_path = File.join(collection_root, 'data')
      doc_ln_target = File.join(doc_source_path, '_Documentation')
      system('ln', '-s', ingest_params.doc_source, doc_ln_target)
      # FileUtils.ln_s ingest_params.doc_source, doc_source_path
      doc_package.source_path = doc_source_path

      ingest_manifest
    end

    def _populate_missing_attribute(ingest_manifest:, write_target:)
      mmap = Manifests::ManifestMissingAttributePopulator.new(file_identifier:)
      manifest = mmap.populate_missing_attribute(manifest: ingest_manifest)
      File.write(write_target, JSON.pretty_generate(manifest.to_json_ingest_hash))

      manifest
    end

    def _compare_asset_existence(ingest_manifest:)
      mfc = Manifests::ManifestToFilesystemComparator.new
      mfc.compare_manifest_to_filesystem(manifest: ingest_manifest)
    end

    # We need to halt the preparation if there is any overwrites.
    # For IPP, we need the merged storage manifest when overwrites are detected.
    def _initialize_collection_manifest(im_path:)
      manifest = if ingest_params.new_collection?
                   _create_collection_manifest(im_path:)
                 else
                   _merge_ingest_manifest_to_collection_manifest(imf: im_path)
                 end
      manifest = _store_collection_manifest(manifest:)
      _check_overwrite(imf: im_path)
      manifest
    end

    def _create_collection_manifest(im_path:)
      manifest = Manifests.read_manifest(filename: im_path)
      manifest.walk_packages { |package| package.source_path = nil }
      manifest
    end

    def _merge_ingest_manifest_to_collection_manifest(imf:)
      cm = _get_storage_manifest
      im = Manifests.read_manifest(filename: imf)
      Manifests.merge_manifests(storage_manifest: cm, ingest_manifest: im)
    end

    def _check_overwrite(imf:)
      ingest_manifest = Manifests.read_manifest(filename: imf)
      overwrites = overwrite_checker.check_overwrites(ingest_manifest:)
      return unless overwrites.any?

      msg = overwrites.join("\n")
      raise IngestException, "Overwrite detected:\n#{msg}"
    end

    def _get_storage_manifest
      file = Tempfile.new('storage_manifest')
      key = "#{ingest_params.depositor}/#{ingest_params.collection}/#{ingest_params.existing_storage_manifest}"
      manifest_str = wasabi_manager.retrieve_file(key)
      manifest = Manifests.read_manifest_io(json_io: manifest_str)
      file.unlink
      manifest
    end

    def _store_collection_manifest(manifest:)
      manifest_dir = File.join(collection_root, 'manifest')
      collection_manifest_dir = File.join(manifest_dir, 'collection_manifest')
      cm_filename = Manifests.collection_manifest_filename(depositor:, collection: collection_id)
      FileUtils.mkdir_p(collection_manifest_dir)
      manifest_path = File.join(collection_manifest_dir, cm_filename)

      json_to_write = JSON.pretty_generate(manifest.to_json_storage_hash)
      File.write(manifest_path, json_to_write)
    end

    def generate_config(ingest_manifest_path:)
      { type: work_type, depositor:, collection: collection_id,
        ingest_manifest: ingest_manifest_path, ticket_id: ingest_params.ticketid }
    end

    def work_type
      IngestMessage::TYPE_INGEST
    end

    def config_path
      File.join(collection_root, 'config', 'ingest_config.yaml')
    end
  end
end
