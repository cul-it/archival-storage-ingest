# frozen_string_literal: true

require 'archival_storage_ingest'
require 'archival_storage_ingest/s3/s3_manager'
require 'aws-sdk-core/shared_credentials'
require 'aws-sdk-s3'
require 'aws-sdk-ssm'

module IngestUtils
  class ConfigureHelper
    attr_reader :stage, :s3_bucket, :wasabi_bucket, :debug, :develop, :message_queue_name, :in_progress_queue_name, :dest_queue_names

    def initialize(params)
      @stage = ArchivalStorageIngest::STAGE_PROD
      @stage = ArchivalStorageIngest::STAGE_DEV if params[:asi_develop]
      @stage = ArchivalStorageIngest::STAGE_SANDBOX if params[:asi_sandbox]

      @s3_bucket = stage == ArchivalStorageIngest::STAGE_PROD ? 's3-cular' : "s3-cular-#{stage}"
      @wasabi_bucket = stage == ArchivalStorageIngest::STAGE_PROD ? 'wasabi-cular' : "wasabi-cular-#{stage}"
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
      config.wasabi_bucket = wasabi_bucket

      config
    end

    # def configure_wasabi_manager(stage)
    #   wasabi_cred = wasabi_credentials(stage)
    #   wasabi_client = Aws::S3::Client.new(credentials: wasabi_cred, region: 'us-east-1' , endpoint: 'https://s3.wasabisys.com')
    #   wasabi_resource = Aws::S3::Resource.new(client: wasabi_client)
    #   wasabi_bucket = wasabi_bucket(stage)
    #   wasabi_manager = S3Manager.new(wasabi_bucket)
    #   wasabi_manager.s3 = wasabi_resource
    #   wasabi_manager
    # end

    # def wasabi_credentials(stage)
    #   ssm_client ||= Aws::SSM::Client.new
    #   wasabi_aki = ssm_param(ssm_client, "/cular/archivalstorage/#{stage}/ingest/wasabi/access_key_id")
    #   wasabi_sak = ssm_param(ssm_client, "/cular/archivalstorage/#{stage}/ingest/wasabi/secret_access_key")
    #   Aws::Credentials.new(wasabi_aki, wasabi_sak)
    # end

    # def wasabi_bucket(stage)
    #   case stage
    #   when ArchivalStorageIngest::STAGE_PROD
    #     'wasabi-cular'
    #   when ArchivalStorageIngest::STAGE_DEV
    #     'wasabi-cular-dev'
    #   when ArchivalStorageIngest::STAGE_SANDBOX
    #     'wasabi-sandbox?'
    #   end
    # end

    def ssm_param(ssm_client, param, with_decryption: true)
      ssm_client.get_parameter({ name: param, with_decryption: with_decryption }).parameter.value
    end
  end
end
