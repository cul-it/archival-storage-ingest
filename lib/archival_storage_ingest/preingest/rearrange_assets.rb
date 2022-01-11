# frozen_string_literal: true

require 'csv'

# filepath,size,sha1,JHOVE_timestamp,pid,ingest_date_calculated,to_documentation,migrated_name
module Preingest
  class AssetRearranger
    def source_path_key
      'filepath'
    end

    def new_path_key
      'migrated_name'
    end

    def rearrange_data_structure(depositor:, collection:, arrange_info_csv:, source_path:, staging_root:)
      staging_path = File.join(staging_root, depositor, collection)
      arrange_info = populate_arrange_info(arrange_info_csv: arrange_info_csv)

      arrange_info.each_pair do |key, value|
        rearrange_asset(source_path: File.join(source_path, key), staging_path: File.join(staging_path, value))
      end
    end

    def populate_arrange_info(arrange_info_csv:)
      arrange_info = {}
      CSV.foreach(arrange_info_csv, headers: true) do |row|
        next if skip_row(row: row)

        arrange_info[row[source_path_key]] = if row[new_path_key] == 'SAME'
                                               row[source_path_key]
                                             else
                                               row[new_path_key]
                                             end
      end

      arrange_info
    end

    def rearrange_asset(source_path:, staging_path:)
      parent = File.dirname(staging_path)
      FileUtils.mkdir_p(parent)
      File.symlink(source_path, staging_path)
    end

    def skip_row(row:)
      row['to_documentation'] == 'Y'
    end
  end
end
