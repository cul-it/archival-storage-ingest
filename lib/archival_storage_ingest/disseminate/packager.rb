# frozen_string_literal: true

require 'archival_storage_ingest/exception/ingest_exception'
require 'zip'

module Disseminate
  class Packager
    def package_dissemination(zip_filepath:, depositor:, collection:, transferred_packages:)
      Zip.write_zip64_support = true
      Zip::File.open(zip_filepath, Zip::File::CREATE) do |zip_file|
        transferred_packages.each_value do |package|
          package.each do |filepath, abs_filepath|
            zip_file.add("#{depositor}/#{collection}/#{filepath}", abs_filepath)
          end
        end
      end

      zip_filepath
    end
  end
end
