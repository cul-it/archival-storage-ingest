# frozen_string_literal: true

require 'aws-sdk-ssm'
require 'net/http'
require 'opensearch'
require 'time'

module ArchivalStorageIngestLogger
  INDEX_TYPE_INGEST = 'ingest'
  INDEX_TYPE_PERIODIC_FIXITY = 'periodic_fixity'
  MAX_RETRY = 3

  def self.get_application_logger(stage:, index_type:, use_lambda_logger: false)
    if use_lambda_logger
      ArchivalStorageIngestLogger::LambdaLogger.new(stage: stage, type: index_type)
    else
      ArchivalStorageIngestLogger::OpenSearchLogger.new(stage: stage, type: index_type)
    end
  end

  class ApplicationLogger
    attr_writer :ssm_client

    def ssm_client
      @ssm_client ||= Aws::SSM::Client.new
    end

    def initialize(stage:, type:)
      @index_name = "cular_#{stage}_#{type}-log"
    end

    def ssm_param(param, with_decryption: false)
      ssm_client.get_parameter({ name: param, with_decryption: with_decryption }).parameter.value
    end

    def log(log_document)
      retry_count = 0
      MAX_RETRY.times do
        return _log(log_document)

      rescue StandardError
        retry_count += 1
        raise if retry_count > 2
      end
    end

    def _log(_log_document); end
  end

  class OpenSearchLogger < ApplicationLogger
    def initialize(stage:, type:)
      super(stage: stage, type: type)
      opensearch_url = ssm_param("/cular/archivalstorage/#{stage}/application_logger/opensearch/opensearch_url")
      opensearch_main_user = ssm_param("/cular/archivalstorage/#{stage}/application_logger/opensearch/opensearch_main_user")
      opensearch_main_password = ssm_param("/cular/archivalstorage/#{stage}/application_logger/opensearch/opensearch_main_password",
                                           with_decryption: true)

      @client = OpenSearch::Client.new(
        host: opensearch_url, user: opensearch_main_user, password: opensearch_main_password,
        port: '443', scheme: 'https'
      )
    end

    def _log(log_document)
      return if log_document.nil?

      log_document[:timestamp] = Time.now.utc.iso8601(3)
      @client.index(
        index: @index_name,
        body: log_document
      )
    end
  end

  class LambdaLogger < ApplicationLogger
    def initialize(stage:, type:)
      super(stage: stage, type: type)
      @os_lambda_url = URI.parse(ssm_param("/cular/archivalstorage/#{stage}/opensearch/#{type}_lambda_url"))
      @os_lambda_https = Net::HTTP.new(@os_lambda_url.host, @os_lambda_url.port)
      @os_lambda_https.use_ssl = true
    end

    def _log(log_document)
      return if log_document.nil?

      request = Net::HTTP::Post.new(@os_lambda_url.path)
      log_document[:timestamp] = Time.now.utc.iso8601(3)
      request.body = log_document.to_json
      response = @os_lambda_https.request(request)
      response.body
    end
  end
end
