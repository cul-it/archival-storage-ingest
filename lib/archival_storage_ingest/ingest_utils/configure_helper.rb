# frozen_string_literal: true

require 'archival_storage_ingest'

module IngestUtils
  class ConfigureHelper
    attr_reader :stage, :s3_bucket, :debug, :develop, :message_queue_name, :in_progress_queue_name, :dest_queue_names

    def initialize(params)
      @stage = ArchivalStorageIngest::STAGE_PROD
      @stage = ArchivalStorageIngest::STAGE_DEV if params[:asi_develop]
      @stage = ArchivalStorageIngest::STAGE_SANDBOX if params[:asi_sandbox]

      @s3_bucket = stage == ArchivalStorageIngest::STAGE_PROD ? 's3-cular' : "s3-cular-#{stage}"
      @develop = stage != ArchivalStorageIngest::STAGE_PROD
      @debug = stage != ArchivalStorageIngest::STAGE_PROD

      configure_queues(params)
    end

    def configure_queues(params)
      @message_queue_name = Queues.resolve_queue_name(stage: stage, queue: params[:queue_name])
      @in_progress_queue_name = Queues.resolve_in_progress_queue_name(stage: stage, queue: params[:queue_name])
      @dest_queue_names = []
      params[:dest_queue_names].each do |dest_queue_name|
        dest_queue_names.append(Queues.resolve_queue_name(queue: dest_queue_name, stage: stage))
      end
    end

    def configure(config)
      config.stage = stage
      config.message_queue_name = message_queue_name
      config.in_progress_queue_name = in_progress_queue_name
      config.dest_queue_names = dest_queue_names
      config.develop = develop
      config.debug = debug
      config.s3_bucket = s3_bucket

      config
    end
  end
end
