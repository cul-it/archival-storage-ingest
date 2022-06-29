# frozen_string_literal: true

require 'aws-sdk-ssm'
require 'net/http'
require 'opensearch'
require 'time'

module ArchivalStorageIngestLogger
  INDEX_TYPE_INGEST = 'ingest'
  INDEX_TYPE_PERIODIC_FIXITY = 'periodic_fixity'

  def self.get_application_logger(stage:, index_type:, use_lambda_logger: false)
    if use_lambda_logger
      ArchivalStorageIngestLogger::LambdaLogger.new(stage: stage, type: index_type)
    else
      ArchivalStorageIngestLogger::ApplicationLogger.new(stage: stage, type: index_type)
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

    def log(_log_document); end
  end

  class OpenSearchLogger < ApplicationLogger
    def initialize(stage:, type:)
      super(stage: stage, type: type)
      opensearch_url = ssm_param("/cular/archivalstorage/#{stage}/opensearch/opensearch_url")
      opensearch_main_user = ssm_param("/cular/archivalstorage/#{stage}/opensearch/opensearch_main_user")
      opensearch_main_password = ssm_param("/cular/archivalstorage/#{stage}/opensearch/opensearch_main_password",
                                           with_decryption: true)

      @client = OpenSearch::Client.new(
        host: opensearch_url, user: opensearch_main_user, password: opensearch_main_password,
        port: '443', scheme: 'https'
      )
    end

    def log(log_document)
      return if log_document.nil?

      log_document[:timestamp] = Time.now.utc.iso8601(3)
      @client.index(
        index: @index_name,
        body: log_document,
        refresh: true
      )
    end
  end

  class LambdaLogger < ApplicationLogger
    def initialize(stage:, type:)
      super(stage: stage, type: type)
      @os_lambda_url = URI.parse(ssm_param("/cular/archivalstorage/#{stage}/opensearch/#{type}_lambda_url"))
      @os_lambda_https = Net::HTTP.new(url.host, url.port)
      @os_lambda_https.use_ssl = true
    end

    def log(log_document)
      return if log_document.nil?

      request = Net::HTTP::Post.new(@os_lambda_url.path)
      log_document[:timestamp] = Time.now.utc.iso8601(3)
      request.body = log_document.to_json
      response = @os_lambda_https.request(request)
      response.body
    end
  end
end
