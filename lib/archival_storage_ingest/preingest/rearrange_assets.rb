# frozen_string_literal: true

require 'csv'

# filepath,size,sha1,JHOVE_timestamp,pid,ingest_date_calculated,to_documentation,migrated_name
module Preingest
  class AssetRearranger
    attr_accessor :old_path_key, :new_path_key

    def initialize(old_path_key:, new_path_key:)
      @old_path_key = old_path_key
      @new_path_key = new_path_key
    end

    def rearrange_data_structure(depositor:, collection:, arrange_info_csv:, source_path:, staging_root:)
      staging_path = File.join(staging_root, depositor, collection)
      arrange_info = populate_arrange_info(arrange_info_csv:)

      arrange_info.each_pair do |new_path, old_path|
        rearrange_asset(source_path: File.join(source_path, old_path),
                        staging_path: File.join(staging_path, new_path))
      end
    end

    def populate_arrange_info(arrange_info_csv:)
      arrange_info = {}
      CSV.foreach(arrange_info_csv, headers: true) do |row|
        old_path = row[old_path_key]
        new_path = row[new_path_key]
        new_path = old_path if new_path == 'SAME'

        arrange_info[new_path] = old_path
      end

      arrange_info
    end

    def rearrange_asset(source_path:, staging_path:)
      parent = File.dirname(staging_path)
      FileUtils.mkdir_p(parent)
      File.symlink(source_path, staging_path)
    end
  end
end
