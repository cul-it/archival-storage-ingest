# frozen_string_literal: true

require 'opensearch'
require 'time'

class ApplicationLogger
  attr_writer :ssm_client

  def s3
    @ssm_client ||= Aws::SSM::Client.new
  end

  def initialize(opensearch_url: nil, stage:, index_name:)
    opensearch_url = ssm_param("/cular/archivalstorage/#{stage}/opensearch/opensearch_url") unless opensearch_url
    opensearch_main_user = ssm_param("/cular/archivalstorage/#{stage}/opensearch/opensearch_main_user")
    opensearch_main_password = ssm_param("/cular/archivalstorage/#{stage}/opensearch/opensearch_main_password")

    @client = OpenSearch::Client.new(
      host: opensearch_url,
      user: opensearch_main_user,
      password: opensearch_main_password
    )
    @index_name = index_name
  end

  def ssm_param(param)
    @ssm_client.get_parameter({name: param})
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
