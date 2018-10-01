require 'json'

# Ingest message implementations, currently supports SQS message
module IngestMessage
  TYPE_INGEST         = 'Ingest'.freeze
  TYPE_TRANSFER_S3    = 'Transfer S3'.freeze
  TYPE_TRANSFER_SFS   = 'Transfer SFS'.freeze
  TYPE_FIXITY_S3      = 'Fixity S3'.freeze
  TYPE_FIXITY_SFS     = 'Fixity SFS'.freeze
  TYPE_FIXITY_COMPARE = 'Fixity Compare'.freeze

  def self.to_sqs_message(sqs_message_body)
    json = JSON.parse(sqs_message_body)
    SQSMessage.new(
      ingest_id: json['ingest_id'],
      type: json['type']
    )
  end

  # SQS message implementation
  class SQSMessage
    def initialize(params)
      @ingest_id = params[:ingest_id]
      @type      = params[:type]
    end

    attr_reader :ingest_id
    attr_accessor :type

    def to_json
      JSON.generate(
        ingest_id: ingest_id,
        type:      type
      )
    end
  end
end
