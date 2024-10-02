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
      @errors << "Queue name #{ingest_config[:queue_name]} is not valid!" unless
        valid_queue_name?(ingest_config[:queue_name])

      @errors.empty?
    end

    def valid_queue_name?(queue_name)
      return true if queue_name.nil?

      Queues.valid_queue_name?(queue_name)
    end
  end

  class IngestInputChecker < InputChecker
    attr_accessor :ingest_manifest

    def check_input(ingest_config)
      super

      ingest_manifest = ingest_config[:ingest_manifest].to_s.strip
      if File.exist?(ingest_manifest)
        ingest_manifest_errors(ingest_config[:ingest_manifest])
      else
        @errors << "ingest_manifest #{ingest_manifest} does not exist!" unless
          File.exist?(ingest_manifest)
      end

      @errors.empty?
    end

    def ingest_manifest_errors(input_im)
      @ingest_manifest = Manifests.read_manifest(filename: input_im)
      @ingest_manifest.walk_packages do |package|
        @errors << "Source path for package #{package.package_id} is not valid!" unless
          File.exist?(package.source_path.to_s)
      end
      @errors.empty?
    end
  end

  # NOTE: Disabled because of reliance on SFS
  # class FixityInputChecker < InputChecker
  #   def dest_path_ok?(dest_path)
  #     dest_paths = dest_path.split(FixityWorker::PeriodicFixitySFSGenerator::DEST_PATH_DELIMITER)
  #     status = true
  #     dest_paths.each do |path|
  #       unless super(path)
  #         status = false
  #         break
  #       end
  #     end
  #     status
  #   end
  # end

  # Use this class in tests where you want to bypass input check ONLY!
  class YesManInputChecker < InputChecker
    def check_input(_ingest_config)
      0
    end
  end
end
