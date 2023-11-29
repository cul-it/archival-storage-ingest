# frozen_string_literal: true

require 'archival_storage_ingest/manifests/manifests'
require 'securerandom'

module Manifests
  class PackageHelper
    attr_reader :package_id_map, :new_packages, :depth, :source_path

    def initialize(manifest:, depth:, source_path:)
      @package_id_map = {}
      @depth = depth
      @source_path = source_path
      @new_packages = []
      manifest.walk_packages do |package|
        package_id_path = package_identifier(filepath: package.files[0].filepath)
        @package_id_map[package_id_path] = package
      end
    end

    def find_package_id(filepath:)
      package_id_path = package_identifier(filepath:)
      package = package_id_map[package_id_path]
      unless package
        package = Manifests::Package.new(
          package: { package_id: "urn:uuid:#{SecureRandom.uuid}" }
        )
        package_id_map[package_id_path] = package
      end
      package.package_id
    end

    # We break packages by nth deep directory path.
    # For example, for most collections, it is the first directory (1).
    # For IPP, it is 2.
    def package_identifier(filepath:)
      filepath.split('/').first(depth).join('/')
    end
  end
end
