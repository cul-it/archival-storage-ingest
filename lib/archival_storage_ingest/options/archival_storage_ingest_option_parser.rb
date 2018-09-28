require 'optparse'
require 'archival_storage_ingest'

# option parser
module ArchivalStorageIngestOptionParser
  # command line option parser
  class CommandlineOptionParser
    def initialize
      @server_command = nil
      @ingest_config  = nil
    end

    def valid_server_command?(command)
      [ArchivalStorageIngest::COMMAND_SERVER_START,
       ArchivalStorageIngest::COMMAND_SERVER_STATUS,
       ArchivalStorageIngest::COMMAND_SERVER_STOP].include?(command)
    end

    def parse(argv)
      options = {}
      OptionParser.new do |opts|
        opts.banner = 'Usage: archival_storage_ingest -s [server options] or -i [ingest_config_path]'

        opts.on('-s COMMAND', '--server COMMAND', 'COMMAND, one of start, status, stop, defaults to status') do |s|
          options[:server_command] = s
        end

        opts.on('-i INGEST_CONFIG', '--ingest_config INGEST_CONFIG', 'Ingest config file') do |i|
          options[:ingest_config] = i
        end
      end.parse!

      raise 'One of -s or -i flag is required' if options[:server_command].nil? && options[:ingest_config].nil?

      if !options[:server_command].nil? && !valid_server_command?(options[:server_command])
        error_msg = 'Invalid server command given: ' + options[:server_command] +
            '. valid commands are: ' +
            ArchivalStorageIngest::COMMAND_SERVER_START + ', ' +
            ArchivalStorageIngest::COMMAND_SERVER_STATUS + ' and ' +
            ArchivalStorageIngest::COMMAND_SERVER_STOP
        raise error_msg
      elsif !options[:ingest_config].nil? && !File.file?(options[:ingest_config])
        raise options[:ingest_config] + ' is not a valid file'
      end

      @server_command = options[:server_command]
      @ingest_config  = options[:ingest_config]
    end

    attr_reader :server_command, :ingest_config
  end
end