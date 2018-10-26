class IngestException < StandardError
  DEFAULT_ERROR_MESSAGE = 'Automated ingest encountered error'.freeze
  def initialize(msg = :DEFAULT_ERROR_MESSAGE)
    super
  end
end