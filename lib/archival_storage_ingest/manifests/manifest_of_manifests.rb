# frozen_string_literal: true

require 'archival_storage_ingest/ingest_utils/ingest_utils'
require 'json'

module Manifests
  def self.create_manifest_definition(storage_manifest_path:, sfs:)
    abort 'sfs must be provided for new collection!' if IngestUtils.blank?(sfs)

    storage_manifest = Manifests.read_manifest(filename: storage_manifest_path)
    depositor = storage_manifest.depositor
    collection = storage_manifest.collection_id
    params = { depositor: depositor, collection: collection, path: File.basename(storage_manifest_path),
               sha1: IngestUtils.calculate_checksum(filepath: storage_manifest_path)[0], sfs: [sfs],
               s3key: "#{depositor}/#{collection}/#{File.basename(storage_manifest_path)}",
               depcol: "#{depositor}/#{collection}" }
    ManifestDefinition.new(params)
  end

  class ManifestOfManifests
    attr_accessor :mom_path, :manifest_of_manifests

    def initialize(manifests_path)
      @mom_path = manifests_path
      f = File.new(manifests_path, 'r')
      mom_hash = JSON.parse(f.read, symbolize_names: true)
      f.close
      @manifest_of_manifests = []
      mom_hash.each do |manifest_def_hash|
        @manifest_of_manifests << ManifestDefinition.new(manifest_def_hash)
      end
    end

    def manifest_definition(depositor:, collection:)
      manifest_of_manifests.find { |i| i.depositor.eql?(depositor) && i.collection.eql?(collection) }
    end

    def next_manifest_definition(depositor:, collection:)
      index = manifest_of_manifests.find_index { |i| i.depositor.eql?(depositor) && i.collection.eql?(collection) }
      manifest_of_manifests[index + 1]
    end

    def add_manifest_definition(storage_manifest_path:, sfs:)
      new_manifest_def = Manifests.create_manifest_definition(storage_manifest_path: storage_manifest_path, sfs: sfs)
      @manifest_of_manifests << new_manifest_def

      new_manifest_def
    end

    def to_hash
      mom = []
      manifest_of_manifests.each do |m_def|
        mom << m_def.to_hash
      end

      mom
    end

    def save(dest: nil)
      destination = dest.nil? ? @mom_path : dest

      file = File.new(destination, 'w')
      output = JSON.pretty_generate(to_hash)
      file.write(output)
      file.close

      destination
    end
  end

  class ManifestDefinition
    attr_accessor :depositor, :collection, :sha1, :sfs, :depcol, :path, :s3_key

    def initialize(manifest_def_hash)
      @depositor = manifest_def_hash[:depositor]
      @collection = manifest_def_hash[:collection]
      @sha1 = manifest_def_hash[:sha1]
      @sfs = manifest_def_hash[:sfs]
      @depcol = manifest_def_hash[:depcol]
      @path = manifest_def_hash[:path]
      @s3_key = manifest_def_hash[:s3key]
    end

    def to_hash
      {
        depositor: depositor, collection: collection, sha1: sha1, sfs: sfs,
        depcol: depcol, path: path, s3_key: s3_key
      }.compact
    end
  end
end
