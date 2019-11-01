# frozen_string_literal: true

require 'json'

module Manifests
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
  end
end
