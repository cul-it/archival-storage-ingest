# frozen_string_literal: true

require 'archival_storage_ingest/ingest_utils/ingest_utils'
require 'archival_storage_ingest/manifests/manifests'
require 'fileutils'
require 'json'

module Manifests
  SFS_PREFIX = '/cul/data'
  class CollectionManifestDeployer
    def initialize(manifests_path:, s3_manager:)
      f = File.new(manifests_path, 'r')
      @manifest_of_manifests = JSON.parse(f.read, symbolize_names: true)
      f.close
      @mom_path = manifests_path
      @s3_manager = s3_manager
    end

    def prepare_manifest_definition(collection_manifest:, sfs: nil)
      cm_obj = Manifests.read_manifest(filename: collection_manifest)
      manifest_def = manifest_definition(cm_path: collection_manifest, collection_manifest: cm_obj)
      if manifest_def.nil?
        manifest_def = add_manifest_definition(cm_path: collection_manifest,
                                               collection_manifest: cm_obj, sfs: sfs)
      end
      manifest_def
    end

    def manifest_definition(cm_path:, collection_manifest:)
      definition_index = @manifest_of_manifests.find_index do |manifest_definition|
        manifest_definition[:depositor] == collection_manifest.depositor &&
          manifest_definition[:collection] == collection_manifest.collection_id
      end
      return nil if definition_index.nil?

      @manifest_of_manifests[definition_index][:sha1] = IngestUtils.calculate_checksum(cm_path)[0]
      @manifest_of_manifests[definition_index]
    end

    # currently supports only single sfs
    def add_manifest_definition(cm_path:, collection_manifest:, sfs:)
      abort 'sfs must be provided for new collection!' if IngestUtils.blank?(sfs)

      depositor = collection_manifest.depositor
      collection = collection_manifest.collection_id
      manifest_definition = {
        depositor: depositor, collection: collection, sha1: IngestUtils.calculate_checksum(cm_path)[0],
        sfs: [sfs], path: cm_path, s3key: "#{depositor}/#{collection}/#{File.basename(cm_path)}",
        depcol: "#{collection_manifest.depositor}/#{collection_manifest.collection_id}"
      }
      @manifest_of_manifests << manifest_definition
      manifest_definition
    end

    def describe_deployment(manifest_def:)
      manifest_def.keys.sort.each do |key|
        puts "#{key}: #{manifest_def[key]}"
      end
    end

    def deploy_collection_manifest(manifest_def:, collection_manifest:)
      deploy_sfs(cm_path: collection_manifest, manifest_def: manifest_def)
      deploy_s3(cm_path: collection_manifest, manifest_def: manifest_def)
      deploy_manifest_definition
    end

    def deploy_sfs(cm_path:, manifest_def:)
      manifest_def[:sfs].each do |sfs|
        target = File.join(SFS_PREFIX, sfs, manifest_def[:depositor], manifest_def[:collection], manifest_def[:path])
        FileUtils.copy(cm_path, target)
      end
    end

    def deploy_s3(cm_path:, manifest_def:)
      @s3_manager.upload_file(manifest_def[:s3key], cm_path)
    end

    def deploy_manifest_definition
      file = File.new(@mom_path, 'w')
      output = JSON.pretty_generate(@manifest_of_manifests)
      file.write(output)
      file.close
      puts 'Manifest of manifest is updated.  Please commit the change.'
    end
  end
end
