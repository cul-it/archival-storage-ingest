require 'json'

module IngestMessage
  TYPE_TRANSFER_S3    = 'Transfer S3'
  TYPE_TRANSFER_SFS   = 'Transfer SFS'
  TYPE_FIXITY_S3      = 'Fixity S3'
  TYPE_FIXITY_SFS     = 'Fixity SFS'
  TYPE_FIXITY_COMPARE = 'Fixity Compare'

  def to_sqs_message(json)
    return SQSMessage.new({
      ingest_id: json[:ingest_id],
      type: json[:type]
    })
  end

  class SQSMessage
    def initialize(params)
      @ingest_id = params[:ingest_id]
      @type      = params[:type]
    end

    attr_reader :ingest_id
    attr_accessor :type

    def to_json
      return JSON.generate({
        :ingest_id => @ingest_id,
        :type => @type
      })
    end
  end
end
