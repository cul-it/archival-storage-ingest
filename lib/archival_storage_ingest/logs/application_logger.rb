# frozen_string_literal: true

require 'opensearch'
require 'time'

class ApplicationLogger
  def initialize(opensearch_url:, index_name:)
    @client = OpenSearch::Client.new url: opensearch_url, log: true
    @index_name = index_name
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
