# frozen_string_literal: true

require 'archival_storage_ingest/workers/package_handler/base_package_handler'

module M2MWorker
  class ECommonsPackageHandler < BasePackageHandler
    attr_reader :mets_schema

    def initialize(ingest_root:, sfs_root:, queuer:, file_identifier:, manifest_validator:)
      super(ingest_root:, sfs_root:, queuer:,
            file_identifier:, manifest_validator:)
      @mets_schema = File.join(__FILE__, 'schema', 'mets.xsd')
    end

    # validate METS xml
    def validate_msg(_msg:, path:)
      document = "#{path}/mets.xml"
      validate_mets(mets_path: document, schema_path: mets_schema)
    end

    def validate_mets(mets_path:, schema_path:)
      errors = nil
      File.open(schema_path) do |s|
        schema = Nokogiri::XML::Schema(s)
        errors = schema.validate(mets_path)
      end
      errors
    end

    def report_error(_msg:); end

    # A single eCommons package is equal to one eCommons handle, delivered to us in zip format in S3.
    # It follows that for each deposit, there will be one equivalent CULAR package.
    def ingest_manifest(msg:, path:)
      manifest = base_ingest_manifest(msg:)
      package_args = { package_id: package_id(path:), source_path: path,
                       bibid: bibid(path:), local_id: local_id(path:), files: [] }
      package = Manifests::Package.new(package: package_args)
      populate_files(path:).each do |file|
        package.add_file(file:)
      end
      manifest.add_package(package:)
      manifest
    end
  end
end
