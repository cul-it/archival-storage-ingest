# frozen_string_literal: true

require 'json'
require 'pathname'
require 'archival_storage_ingest/manifests/manifests'

module WorkerManifest
  def self.parse_old_manifest(manifest)
    old_manifest = Manifests::Manifest.new(filename: 'not_important.json', json: manifest)
    Manifest.new(params_files: old_manifest.files)
  end

  class Manifest
    def initialize(params_files: nil)
      if params_files.nil?
        @files = {}
        @number_files = 0
      else
        @files = params_files
        @number_files = params_files.size
      end
    end

    attr_reader :files, :number_files

    def add_file(filepath, sha1, size = 0)
      files[filepath] = { sha1: sha1, size: size }
      @number_files += 1
    end

    def walk_manifest(&block)
      files.each(&block)
    end

    def to_old_manifest(depositor, collection)
      depositor_collection = "#{depositor}/#{collection}"
      depositor_collection_as_path = Pathname.new(depositor_collection)
      old_manifest = { depositor_collection => { items: {} } }
      files.each do |filepath, vals|
        key = Pathname.new(filepath).relative_path_from(depositor_collection_as_path).to_s
        old_manifest[depositor_collection][:items][key] = vals
      end
      old_manifest
    end
  end
end
