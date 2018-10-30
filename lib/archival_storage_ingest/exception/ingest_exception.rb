# frozen_string_literal: true

class IngestException < StandardError
  DEFAULT_ERROR_MESSAGE = 'Automated ingest encountered error'
  def initialize(msg = DEFAULT_ERROR_MESSAGE)
    super
  end
end
