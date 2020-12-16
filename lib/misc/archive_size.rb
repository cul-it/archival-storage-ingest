# frozen_string_literal: true

# Get array of paths to SFS archives and return JSON of capacity and usage

require 'json'

module ArchiveSize
  class ArchiveSize
    def initialize(archives:, s3_manager:)
      @archives = archives
      @s3_manager = s3_manager
    end

    # rubocop:disable Metrics/AbcSize
    def archive_size
      json_data = {}
      json_data[:archives] = []
      @archives.each do |a|
        df = `df #{a[:archive]}`
        a[:size] = df.split[8].to_i
        a[:used] = df.split[9].to_i
        a[:available] = df.split[10].to_i
        (json_data[:archives]) << a
      end
      JSON.pretty_generate(json_data)
    end
    # rubocop:enable Metrics/AbcSize

    def deploy_asif_archive_size(archive_size_json = archive_size)
      @s3_manager.upload_asif_archive_size(s3_key: 'cular_archive_space.json', data: archive_size_json)
    end
  end
end
