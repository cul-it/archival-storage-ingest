# frozen_string_literal: true

require 'archival_storage_ingest'

module IngestUtils
  class ConfigureHelper
    def configure(config:, params:)
      config.stage = ArchivalStorageIngest::STAGE_PROD
      config.s3_bucket = 's3-cular'
      config.debug = ENV['asi_debug'] ? true : false
      config.develop = false

      config = configure_stage(config: config, params: params)

      configure_queues(config: config, params: params)
    end

    def configure_stage(config:, params:)
      return config unless params[:asi_develop] || params[:asi_sandbox]

      config.debug = true
      config.develop = true

      config.stage = params[:asi_develop] ? ArchivalStorageIngest::STAGE_DEV : ArchivalStorageIngest::STAGE_SANDBOX
      config.s3_bucket = "s3-cular-#{config.stage}"

      config
    end

    def configure_queues(config:, params:)
      config.message_queue_name = Queues.resolve_queue_name(queue: params[:queue_name], stage: config.stage)
      config.message_queue_name = Queues.resolve_in_progress_queue_name(queue: params[:queue_name], stage: config.stage)
      config.dest_queue_names = []
      params[:dest_queue_names].each do |dest_queue_name|
        config.dest_queue_names.append(Queues.resolve_queue_name(queue: dest_queue_name, stage: config.stage))
      end

      config
    end
  end
end
