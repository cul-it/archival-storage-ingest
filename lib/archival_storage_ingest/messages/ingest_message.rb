# frozen_string_literal: true

require 'json'
require 'archival_storage_ingest/messages/queues'

# Ingest message implementations, currently supports SQS message
module IngestMessage
  TYPE_INGEST = 'Ingest'
  TYPE_TRANSFER_S3 = 'Transfer S3'
  TYPE_TRANSFER_SFS = 'Transfer SFS'
  TYPE_FIXITY_S3 = 'Fixity S3'
  TYPE_FIXITY_SFS = 'Fixity SFS'
  TYPE_FIXITY_COMPARE = 'Fixity Compare'
  WORK_TYPE_TO_QUEUE = {
    TYPE_INGEST => Queues::QUEUE_INGEST,
    TYPE_TRANSFER_S3 => Queues::QUEUE_TRANSFER_S3,
    TYPE_TRANSFER_SFS => Queues::QUEUE_TRANSFER_SFS,
    TYPE_FIXITY_S3 => Queues::QUEUE_FIXITY_S3,
    TYPE_FIXITY_SFS => Queues::QUEUE_FIXITY_SFS,
    TYPE_FIXITY_COMPARE => Queues::QUEUE_FIXITY_COMPARE
  }.freeze

  def self.to_sqs_message(sqs_message)
    json = JSON.parse(sqs_message.body)
    SQSMessage.new(
      ingest_id: json['ingest_id'],
      type: json['type'],
      data_path: json['data_path'],
      dest_path: json['dest_path'],
      original_msg: sqs_message
    )
  end

  def self.queue_name_from_work_type(type)
    WORK_TYPE_TO_QUEUE[type]
  end

  # SQS message implementation
  # original_msg is the message returned by the AWS SQS client
  class SQSMessage
    def initialize(params)
      @ingest_id = params[:ingest_id]
      @type = params[:type]
      @original_msg = params[:original_msg]
      @data_path = params[:data_path]
      @dest_path = params[:dest_path]
    end

    attr_reader :ingest_id, :original_msg, :data_path, :dest_path
    attr_accessor :type

    def to_json
      JSON.generate(
        ingest_id: ingest_id,
        type: type,
        data_path: data_path,
        dest_path: dest_path
      )
    end
  end
end
