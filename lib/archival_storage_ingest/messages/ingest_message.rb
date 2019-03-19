# frozen_string_literal: true

require 'json'
require 'archival_storage_ingest/messages/queues'

# Ingest message implementations, currently supports SQS message
module IngestMessage
  TYPE_INGEST = 'Ingest'
  TYPE_TRANSFER_S3 = 'Transfer S3'
  TYPE_TRANSFER_SFS = 'Transfer SFS'
  TYPE_INGEST_FIXITY_S3 = 'Ingest Fixity S3'
  TYPE_INGEST_FIXITY_SFS = 'Ingest Fixity SFS'
  TYPE_INGEST_FIXITY_COMPARISON = 'Ingest Fixity Comparison'
  TYPE_PERIODIC_FIXITY_S3 = 'Periodic Fixity S3'
  TYPE_PERIODIC_FIXITY_SFS = 'Periodic Fixity SFS'
  TYPE_PERIODIC_FIXITY_COMPARISON = 'Periodic Fixity Comparison'
  WORK_TYPE_TO_QUEUE = {
    TYPE_INGEST => Queues::QUEUE_INGEST,
    TYPE_TRANSFER_S3 => Queues::QUEUE_TRANSFER_S3,
    TYPE_TRANSFER_SFS => Queues::QUEUE_TRANSFER_SFS,
    TYPE_INGEST_FIXITY_S3 => Queues::QUEUE_INGEST_FIXITY_S3,
    TYPE_INGEST_FIXITY_SFS => Queues::QUEUE_INGEST_FIXITY_SFS,
    TYPE_INGEST_FIXITY_COMPARISON => Queues::QUEUE_INGEST_FIXITY_COMPARISON,
    TYPE_PERIODIC_FIXITY_S3 => Queues::QUEUE_PERIODIC_FIXITY_S3,
    TYPE_PERIODIC_FIXITY_SFS => Queues::QUEUE_PERIODIC_FIXITY_SFS,
    TYPE_PERIODIC_FIXITY_COMPARISON => Queues::QUEUE_PERIODIC_FIXITY_COMPARISON
  }.freeze

  def self.convert_sqs_response(sqs_message)
    json = JSON.parse(sqs_message.body)
    SQSMessage.new(
      ingest_id: json['ingest_id'],
      data_path: json['data_path'],
      dest_path: json['dest_path'],
      depositor: json['depositor'],
      collection: json['collection'],
      ingest_manifest: json['ingest_manifest'],
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
      @original_msg = params[:original_msg]
      @data_path = params[:data_path]
      @dest_path = params[:dest_path]
      @depositor = params[:depositor]
      @collection = params[:collection]
      @ingest_manifest = params[:ingest_manifest]
    end

    attr_reader :ingest_id, :original_msg, :data_path, :dest_path, :depositor, :collection, :ingest_manifest

    def effective_data_path
      File.join(data_path, depositor, collection).to_s
    end

    def effective_dest_path
      File.join(dest_path, depositor, collection).to_s
    end

    def collection_s3_prefix
      File.join(depositor, collection).to_s
    end

    def to_json(_opts)
      JSON.generate(
        ingest_id: ingest_id,
        data_path: data_path,
        dest_path: dest_path,
        depositor: depositor,
        collection: collection,
        ingest_manifest: ingest_manifest
      )
    end
  end
end
