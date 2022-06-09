# frozen_string_literal: true

require 'opensearch'
require 'time'

module ArchivalStorageIngestLogger
  INDEX_TYPE_INGEST = 'ingest'
  INDEX_TYPE_PERIODIC_FIXITY = 'periodic_fixity'

  class ApplicationLogger
    attr_writer :ssm_client

    def ssm_client
      @ssm_client ||= Aws::SSM::Client.new
    end

    def initialize(stage:, type:)
      opensearch_url = ssm_param("/cular/archivalstorage/#{stage}/opensearch/opensearch_url")
      opensearch_main_user = ssm_param("/cular/archivalstorage/#{stage}/opensearch/opensearch_main_user")
      opensearch_main_password = ssm_param("/cular/archivalstorage/#{stage}/opensearch/opensearch_main_password",
                                           with_decryption: true)

      @client = OpenSearch::Client.new(
        host: opensearch_url,
        user: opensearch_main_user,
        password: opensearch_main_password
      )
      @index_name = "cular_#{stage}_#{type}-log"
    end

    def ssm_param(param, with_decryption: false)
      @ssm_client.get_parameter({ name: param, with_decryption: with_decryption })
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
end
