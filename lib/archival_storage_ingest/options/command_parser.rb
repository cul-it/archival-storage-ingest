# frozen_string_literal: true

require 'optparse'
require 'archival_storage_ingest/exception/ingest_exception'

# option parser
module CommandParser
  # ingest command line option parser
  class IngestCommandParser
    def initialize
      @ingest_config = nil
    end

    def parse!(args)
      options = {}
      OptionParser.new do |opts|
        opts.banner = 'Usage: archival_storage_ingest -i [ingest_config_path]'

        opts.on('-i INGEST_CONFIG', '--ingest_config INGEST_CONFIG', 'Ingest config file') do |i|
          options[:ingest_config] = i
        end
      end.parse!(args)

      raise IngestException, options[:ingest_config] + ' is not a valid file' unless
          File.file?(options[:ingest_config])

      @ingest_config = options[:ingest_config]
    end

    attr_reader :ingest_config
  end

  class MoveMessageCommandParser
    def initialize
      @config = {}
    end

    def parse!(args)
      OptionParser.new do |opts|
        opts.banner = 'Usage: archival_storage_move_message -s [source queue name] -t [target queue name]'

        opts.on('-s source queue name', '--source_q source queue name', 'Source queue name') do |s|
          config[:source] = s
        end

        opts.on('-t target queue name', '--target_q target queue name', 'Target queue name') do |t|
          config[:target] = t
        end
      end.parse!(args)
    end

    attr_reader :config
  end
end
