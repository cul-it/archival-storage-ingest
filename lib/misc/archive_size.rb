# frozen_string_literal: true

# Get array of paths to SFS archives and return JSON of capacity and usage

require 'json'

module ArchiveSize
    class ArchiveSize
        def initialize(archives:)
            @archives = archives
        end
        def archive_size
            json_data = {}
            json_data[:archives] = []
            for a in @archives do
                df = `df #{a[:path]}`
                a[:size] = df.split[8]
                a[:used] = df.split[9]
                a[:available] = df.split[10]
                (json_data[:archives]) << a
            end
            JSON.pretty_generate(json_data)
        end
    end
end
