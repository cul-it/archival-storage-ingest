# frozen_string_literal: true

require 'archival_storage_ingest/manifests/manifests'
require 'archival_storage_ingest/manifests/package_helper'
require 'nokogiri'

module Manifests
  # It currently assumes that source_path is same for all packages.
  # Change the logic if that is not the case.
  class ConvertXmlToJsonManifest
    def generate_ingest_manifest(xml:, manifest:, depth:, source_path:)
      ingest_manifest = generate_base_manifest(manifest: manifest)
      package_helper = Manifests::PackageHelper.new(manifest: manifest, depth: depth, source_path: source_path)
      walk_xml(xml) do |node|
        add_to_json_manifest(node: node, package_helper: package_helper, ingest_manifest: ingest_manifest)
      end
      overwrite_list = list_overwrite(collection_manifest: manifest, ingest_manifest: ingest_manifest)
      ConvertedResponse.new(ingest_manifest: ingest_manifest, overwrite_list: overwrite_list)
    end

    def add_to_json_manifest(node:, package_helper:, ingest_manifest:)
      filepath = clean_filepath(filepath: node.at_css('filename').content)
      package = get_package(ingest_manifest: ingest_manifest, package_helper: package_helper, filepath: filepath)

      size = node.at_css('filesize').content.to_s.to_i
      sha1 = node.at_css('hashdigest[type="SHA1"]').content.to_s
      package.add_file_entry(filepath: filepath, sha1: sha1, size: size)
    end

    # IPP xml manifest has windows separator "\" and needs to be replaced to "/"
    def clean_filepath(filepath:)
      filepath = filepath[1..] if filepath[0] == '\\'
      filepath.gsub('\\', '/')
    end

    def get_package(ingest_manifest:, package_helper:, filepath:)
      package_id = package_helper.find_package_id(filepath: filepath)
      package = ingest_manifest.get_package(package_id: package_id)
      unless package
        package = Manifests::Package.new(
          package: { package_id: package_id, source_path: package_helper.source_path }
        )
        ingest_manifest.add_package(package: package)
      end
      package
    end

    def walk_xml(xml, &block)
      doc = File.open(xml) { |f| Nokogiri::XML(f) }
      doc.css('dfxml fileobject').each(&block)
    end

    def generate_base_manifest(manifest:)
      base_hash = {
        steward: manifest.steward,
        depositor: manifest.depositor,
        collection_id: manifest.collection_id,
        number_packages: 0,
        packages: []
      }
      Manifests::Manifest.new(json_text: JSON.generate(base_hash))
    end

    def list_overwrite(collection_manifest:, ingest_manifest:)
      overwrite_list = {}
      ingest_manifest.walk_packages do |ingest_package|
        collection_package = collection_manifest.get_package(package_id: ingest_package.package_id)
        next if collection_package.nil?

        overwrite_list = _list_overwrite(collection_package: collection_package,
                                         ingest_package: ingest_package,
                                         overwrite_list: overwrite_list)
      end
      overwrite_list
    end

    def _list_overwrite(collection_package:, ingest_package:, overwrite_list:)
      ingest_package.walk_files do |ingest_file|
        collection_file = collection_package.find_file(filepath: ingest_file.filepath)
        next if collection_file.nil?

        overwrite_list[ingest_file.filepath] = {
          collection_file_entry: collection_file,
          ingest_file_entry: ingest_file
        }
      end
      overwrite_list
    end
  end

  class ConvertedResponse
    attr_reader :ingest_manifest, :overwrite_list

    def initialize(ingest_manifest:, overwrite_list:)
      @ingest_manifest = ingest_manifest
      @overwrite_list = overwrite_list
    end
  end
end
