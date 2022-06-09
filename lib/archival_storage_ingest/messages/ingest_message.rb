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
  TYPE_PERIODIC_FIXITY = 'Periodic Fixity'
  TYPE_PERIODIC_FIXITY_S3 = 'Periodic Fixity S3'
  TYPE_PERIODIC_FIXITY_SFS = 'Periodic Fixity SFS'
  TYPE_PERIODIC_FIXITY_COMPARISON = 'Periodic Fixity Comparison'
  TYPE_M2M = 'M2M Ingest'
  WORK_TYPE_TO_QUEUE = {
    TYPE_INGEST => Queues::QUEUE_INGEST,
    TYPE_TRANSFER_S3 => Queues::QUEUE_TRANSFER_S3,
    TYPE_TRANSFER_SFS => Queues::QUEUE_TRANSFER_SFS,
    TYPE_INGEST_FIXITY_S3 => Queues::QUEUE_INGEST_FIXITY_S3,
    TYPE_INGEST_FIXITY_SFS => Queues::QUEUE_INGEST_FIXITY_SFS,
    TYPE_INGEST_FIXITY_COMPARISON => Queues::QUEUE_INGEST_FIXITY_COMPARISON,
    TYPE_PERIODIC_FIXITY => Queues::QUEUE_PERIODIC_FIXITY,
    TYPE_PERIODIC_FIXITY_S3 => Queues::QUEUE_PERIODIC_FIXITY_S3,
    TYPE_PERIODIC_FIXITY_SFS => Queues::QUEUE_PERIODIC_FIXITY_SFS,
    TYPE_PERIODIC_FIXITY_COMPARISON => Queues::QUEUE_PERIODIC_FIXITY_COMPARISON
    # TYPE_M2M => Queues::QUEUE_ECOMMONS_INTEGRATION
  }.freeze

  def self.convert_sqs_response(sqs_message)
    json = JSON.parse(sqs_message.body)
    SQSMessage.new(
      type: json['type'], job_id: json['job_id'], dest_path: json['dest_path'], depositor: json['depositor'],
      collection: json['collection'], ingest_manifest: json['ingest_manifest'], ticket_id: json['ticket_id'],
      package: json['package'], steward: json['steward'], extract_dir: json['extract_dir'],
      log: json['log'], worker: json['worker'], original_msg: sqs_message
    )
  end

  def self.queue_name_from_work_type(type)
    WORK_TYPE_TO_QUEUE[type]
  end

  # SQS message implementation
  # original_msg is the message returned by the AWS SQS client
  # data_path is removed
  class SQSMessage
    attr_reader :type, :job_id, :original_msg, :depositor, :collection, :ticket_id,
                :package, :steward
    attr_accessor :log, :dest_path, :ingest_manifest, :extract_dir, :worker

    # non optional parameters are required unless the process crashed and work in progress was detected.
    def initialize(params)
      @type = params[:type]
      @job_id = params[:job_id]
      @original_msg = params[:original_msg]
      @dest_path = params[:dest_path]
      @depositor = params[:depositor]
      @collection = params[:collection]
      @ingest_manifest = params[:ingest_manifest]
      @ticket_id = params[:ticket_id]
      init_optional_params(params)
    end

    def init_optional_params(params)
      @package = params[:package]
      @steward = params[:steward]
      @extract_dir = params[:extract_dir]
      @log = params[:log]
      @worker = params[:worker]
    end

    def collection_s3_prefix
      "#{depositor}/#{collection}"
    end

    def to_hash
      {
        type: type, job_id: job_id,
        dest_path: dest_path, depositor: depositor,
        collection: collection, ingest_manifest: ingest_manifest,
        ticket_id: ticket_id, package: package, steward: steward,
        extract_dir: extract_dir, log: log, worker: worker
      }.compact
    end

    def to_json(_opts = nil)
      JSON.generate(to_hash)
    end

    def to_pretty_json(_opts = nil)
      JSON.pretty_generate(to_hash)
    end
  end
end
