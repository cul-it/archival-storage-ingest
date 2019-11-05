# frozen_string_literal: true

require 'archival_storage_ingest/messages/queues'
require 'archival_storage_ingest/workers/fixity_worker'

module WorkQueuer
  class InputChecker
    attr_accessor :ingest_manifest, :errors
    def initialize
      @errors = []
    end

    # Check whether path/files in ingest_config are actual path/files.
    # Override this method if additional checks are required.
    def check_input(ingest_config)
      # if dest_path is blank, use empty string '' to avoid errors printing it
      dest_path = IngestUtils.if_empty(ingest_config[:dest_path], '')
      @errors << "dest_path '#{dest_path}' does not exist!" unless
        dest_path_ok?(dest_path)

      @errors << "Queue name #{ingest_config[:queue_name]} is not valid!" unless
        valid_queue_name?(ingest_config[:queue_name])

      @errors.size.zero?
    end

    def dest_path_ok?(dest_path)
      return true if File.exist?(dest_path)

      # We store data under /cul/data/archivalxx/DEPOSITOR/COLLECTION
      # If we can find up to archivalxx, we should be OK.
      # We may need to change this behavior when we adopt OCFL.
      without_collection = File.dirname(dest_path)
      without_depositor  = File.dirname(without_collection)

      # The most likely case for '.' is when dest_path is blank.
      return false if without_depositor == '.'

      File.exist?(without_depositor)
    end

    def valid_queue_name?(queue_name)
      return true if queue_name.nil?

      Queues.valid_queue_name?(queue_name)
    end
  end

  class IngestInputChecker < InputChecker
    attr_accessor :ingest_manifest

    def check_input(ingest_config)
      super(ingest_config)

      ingest_manifest = ingest_config[:ingest_manifest].to_s.strip
      if File.exist?(ingest_manifest)
        ingest_manifest_errors(ingest_config[:ingest_manifest])
      else
        @errors << "ingest_manifest #{ingest_manifest} does not exist!" unless
          File.exist?(ingest_manifest)
      end

      @errors.size.zero?
    end

    def ingest_manifest_errors(input_im)
      @ingest_manifest = Manifests.read_manifest(filename: input_im)
      @ingest_manifest.walk_packages do |package|
        @errors << "Source path for package #{package.package_id} is not valid!" unless
          File.exist?(package.source_path.to_s)
      end
      @errors.size.zero?
    end
  end

  class FixityInputChecker < InputChecker
    def dest_path_ok?(dest_path)
      dest_paths = dest_path.split(FixityWorker::PeriodicFixitySFSGenerator::DEST_PATH_DELIMITER)
      status = true
      dest_paths.each do |path|
        unless super(path)
          status = false
          last
        end
      end
      status
    end
  end

  # Use this class in tests where you want to bypass input check ONLY!
  class YesManInputChecker < InputChecker
    def check_input(_ingest_config)
      0
    end
  end
end
