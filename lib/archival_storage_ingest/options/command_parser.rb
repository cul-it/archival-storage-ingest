# frozen_string_literal: true

require 'archival_storage_ingest/exception/ingest_exception'
require 'archival_storage_ingest/ingest_utils/ingest_utils'
require 'optparse'

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

        # ingest_config is an ingest YAML config file set up by running setup_ingest_env.
        opts.on('-i INGEST_CONFIG', '--ingest_config INGEST_CONFIG', 'Ingest config file') do |i|
          options[:ingest_config] = i
        end
      end.parse!(args)

      raise IngestException, "#{options[:ingest_config]} is not a valid file" unless
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

  class SetupIngestEnvCommandParser
    attr_reader :data_path, :depositor, :collection_id, :storage_manifest, :ingest_manifest,
                :sfs_bucket, :ticket_id

    def parse!(args) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      OptionParser.new do |opts|
        opts.banner = 'Usage: setup_ingest_env -p -d -c -s -i -b -t [-n -g -r -j -k -h -m]'

        # Required parameters
        opts.on('-p', '--data_path [String]', 'Data path') { |p| @data_path = p }
        opts.on('-d', '--depositor [String]', 'Depositor') { |d| @depositor = d }
        opts.on('-c', '--collection_id [String]', 'Collection ID') { |c| @collection_id = c }
        opts.on('-s', '--storage_manifest [String]', 'Storage manifest') { |s| @storage_manifest = s }
        opts.on('-i', '--ingest_manifest [String]', 'Ingest manifest') { |i| @ingest_manifest = i }
        opts.on('-b', '--sfs_bucket [String]', 'SFS bucket') { |b| @sfs_bucket = b }
        opts.on('-t', '--ticket_id [String]', 'Jira ticket id') { |t| @ticket_id = t }

        # Optional parameters, default values will be used if not specified
        opts.on('-n', '--notify_email [String]', 'Notify email') { |n| @notify_email = n }
        opts.on('-g', '--ingest_root [String]', 'Ingest root') { |g| @ingest_root = g }
        opts.on('-r', '--sfs_root [String]', 'SFS root') { |r| @sfs_root = r }
        opts.on('-j', '--java_path [String]', 'Java path') { |j| @java_path = j }
        opts.on('-k', '--tika_path [String]', 'Tika path') { |k| @tika_path = k }
        opts.on('-h', '--storage_manifest_schema [String]', 'Storage manifest schema') do |h|
          @storage_manifest_schema = h
        end
        opts.on('-m', '--ingest_manifest_schema [String]', 'Ingest manifest schema') { |m| @ingest_manifest_schema = m }
      end.parse!(args)
    end

    def notify_email
      @notify_email ||= nil
    end

    def ingest_root
      @ingest_root ||= Preingest::DEFAULT_INGEST_ROOT
    end

    def sfs_root
      @sfs_root ||= Preingest::DEFAULT_SFS_ROOT
    end

    def java_path
      @java_path ||= Manifests::FileIdentifier::DEFAULT_JAVA_PATH
    end

    def tika_path
      @tika_path ||= Manifests::FileIdentifier::DEFAULT_TIKA_PATH
    end

    def storage_manifest_schema
      @storage_manifest_schema ||= Manifests::ManifestValidator::DEFAULT_STORAGE_SCHEMA
    end

    def ingest_manifest_schema
      @ingest_manifest_schema ||= Manifests::ManifestValidator::DEFAULT_INGEST_SCHEMA
    end

    def if_blank(param, if_blank)
      IngestUtils.blank?(param) ? if_blank : param
    end
  end

  class SetupPeriodicFixityEnvCommandParser
    attr_reader :storage_manifest, :ticket_id, :sfs_bucket

    def parse!(args)
      OptionParser.new do |opts|
        opts.banner = 'Usage: setup_ingest_env -s -f -t -p -b'

        # Required parameters
        opts.on('-s', '--storage_manifest [String]', 'Storage manifest') { |s| @storage_manifest = s }
        opts.on('-t', '--ticket_id [String]', 'Ticket ID') { |t| @ticket_id = t }
        opts.on('-b', '--sfs_bucket [String]', 'SFS bucket') { |b| @sfs_bucket = b }

        # Optional parameters, default values will be used if not specified
        opts.on('-f', '--sfs_root [String]', 'SFS root') { |f| @sfs_root = f }
        opts.on('-p', '--periodic_fixity_root [String]', 'Periodic fixity root') { |p| @periodic_fixity_root = p }
      end.parse!(args)
    end

    def periodic_fixity_root
      @periodic_fixity_root ||= Preingest::DEFAULT_FIXITY_ROOT
    end

    def sfs_root
      @sfs_root ||= Preingest::DEFAULT_SFS_ROOT
    end
  end
end
