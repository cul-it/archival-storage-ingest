require 'optparse'
require 'archival_storage_ingest'

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

      raise options[:ingest_config] + ' is not a valid file' unless
          File.file?(options[:ingest_config])

      @ingest_config = options[:ingest_config]
    end

    attr_reader :ingest_config
  end

  # server command line option parser
  class ServerCommandParser
    def valid_server_command?(command)
      [ArchivalStorageIngest::COMMAND_SERVER_START,
       ArchivalStorageIngest::COMMAND_SERVER_STATUS,
       ArchivalStorageIngest::COMMAND_SERVER_STOP].include?(command)
    end

    def parse!(args)
      options = {}
      OptionParser.new do |opts|
        opts.banner = 'Usage: archival_storage_ingest_server -s [command]'

        opts.on('-s COMMAND', '--server COMMAND', 'COMMAND, one of start, status, stop') do |s|
          options[:server_command] = s
        end
      end.parse!(args)

      raise 'Invalid server command given: ' + options[:server_command] unless
          valid_server_command?(options[:server_command])

      @server_command = options[:server_command]
    end

    attr_reader :server_command
  end
end