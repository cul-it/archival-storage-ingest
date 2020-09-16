# frozen_string_literal: true

# Get array of paths to SFS archives and return JSON of capacity and usage

require 'json'

module ArchiveSize
  class ArchiveSize
    def initialize(archives:, s3_manager:)
      @archives = archives
      @s3_manager = s3_manager
    end

    def archive_size
      json_data = {}
      json_data[:archives] = []
      @archives.each do |a|
        df = `df #{a[:path]}`
        a[:size] = df.split[8]
        a[:used] = df.split[9]
        a[:available] = df.split[10]
        (json_data[:archives]) << a
      end
      JSON.pretty_generate(json_data)
    end

    def deploy_asif_archive_size
      @s3_manager.upload_asif_manifest(s3_key: 'cular_archive_space.json', file: archive_size)
    end
  end
end
