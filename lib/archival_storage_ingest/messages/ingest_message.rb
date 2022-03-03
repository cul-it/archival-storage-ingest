# frozen_string_literal: true

require 'json'
require 'archival_storage_ingest/messages/queues'

# Ingest message implementations, currently supports SQS message
module IngestMessage
  PLATFORM_SERVERFARM = 'Serverfarm'
  PLATFORM_SFS = 'SFS'
  PLATFORM_AWS = 'AWS'
  PLATFORM_AZURE = 'Azure'
  PLATFORM_S3 = 'S3'
  PLATFORM_WASABI = 'Wasabi'
  TYPE_INGEST = 'Ingest'
  TYPE_TRANSFER = 'Transfer'
  # TYPE_TRANSFER_S3 = 'Transfer S3'
  # TYPE_TRANSFER_SFS = 'Transfer SFS'
  TYPE_INGEST_FIXITY = 'Ingest Fixity'
  # TYPE_INGEST_FIXITY_S3 = 'Ingest Fixity S3'
  # TYPE_INGEST_FIXITY_SFS = 'Ingest Fixity SFS'
  TYPE_INGEST_FIXITY_COMPARISON = 'Ingest Fixity Comparison'
  TYPE_PERIODIC_FIXITY = 'Periodic Fixity'
  # TYPE_PERIODIC_FIXITY_S3 = 'Periodic Fixity S3'
  # TYPE_PERIODIC_FIXITY_SFS = 'Periodic Fixity SFS'
  TYPE_PERIODIC_FIXITY_COMPARISON = 'Periodic Fixity Comparison'
  TYPE_M2M = 'M2M Ingest'
  # WORK_TYPE_TO_QUEUE = {
  #   TYPE_INGEST => Queues::QUEUE_INGEST,
  #   TYPE_TRANSFER_S3 => Queues::QUEUE_TRANSFER_S3,
  #   TYPE_TRANSFER_SFS => Queues::QUEUE_TRANSFER_SFS,
  #   TYPE_INGEST_FIXITY_S3 => Queues::QUEUE_INGEST_FIXITY_S3,
  #   TYPE_INGEST_FIXITY_SFS => Queues::QUEUE_INGEST_FIXITY_SFS,
  #   TYPE_INGEST_FIXITY_COMPARISON => Queues::QUEUE_INGEST_FIXITY_COMPARISON,
  #   TYPE_PERIODIC_FIXITY => Queues::QUEUE_PERIODIC_FIXITY,
  #   TYPE_PERIODIC_FIXITY_S3 => Queues::QUEUE_PERIODIC_FIXITY_S3,
  #   TYPE_PERIODIC_FIXITY_SFS => Queues::QUEUE_PERIODIC_FIXITY_SFS,
  #   TYPE_PERIODIC_FIXITY_COMPARISON => Queues::QUEUE_PERIODIC_FIXITY_COMPARISON,
  #   TYPE_M2M => Queues::QUEUE_ECOMMONS_INTEGRATION
  # }.freeze

  def self.convert_sqs_response(sqs_message)
    json = JSON.parse(sqs_message.body)
    SQSMessage.new(
      type: json['type'], ingest_id: json['ingest_id'], dest_path: json['dest_path'], depositor: json['depositor'],
      collection: json['collection'], ingest_manifest: json['ingest_manifest'], ticket_id: json['ticket_id'],
      package: json['package'], steward: json['steward'], extract_dir: json['extract_dir'],
      worker: json['worker'], agent: json['agent'], platform: json['platform'],
      original_msg: sqs_message,
      log: json['log'], log_identifier: json['log_identifier'], log_report_to_jira: json['log_report_to_jira'],
      log_status: json['log_status'], log_timestamp: json['log_timestamp']
      )
  end

  def self.log_message(ingest_msg, params)
    SQSMessage.new(
      agent: ingest_msg.agent, type: ingest_msg.type, platform: ingest_msg.platform, ingest_id: ingest_msg.ingest_id,
      ticket_id: ingest_msg.ticket_id, log: params[:log], log_identifier: params[:log_identifier],
      log_report_to_jira: params[:log_report_to_jira], log_status: params[:log_status],
      log_timestamp: params[:log_timestamp],
      dest_path: nil, ingest_manifest: nil,
      depositor: ingest_msg[:depositor], collection: ingest_msg[:collection], # are these needed?
      original_msg: ingest_msg
    )
  end

  # def self.queue_name_from_work_type(type)
  #   WORK_TYPE_TO_QUEUE[type]
  # end

  # SQS message implementation
  # original_msg is the message returned by the AWS SQS client
  # data_path is removed
  class SQSMessage
    attr_reader :type, :ingest_id, :original_msg, :depositor, :collection, :ticket_id,
                :package, :steward, :log, :log_identifier,
                :log_report_to_jira, :log_status, :log_timestamp
    attr_accessor :dest_path, :ingest_manifest, :extract_dir, :worker, :agent, :platform

    # non optional parameters are required unless the process crashed and work in progress was detected.
    def initialize(params)
      # required for all messages
      @agent = params[:agent]
      @platform = params[:platform]
      @type = params[:type]
      @ingest_id = params[:ingest_id]
      @original_msg = params[:original_msg]
      @ticket_id = params[:ticket_id]

      init_ingest_params(params)
      init_log_params(params)
      init_optional_params(params)
    end

    def init_optional_params(params)
      @package = params[:package]
      @steward = params[:steward]
      @extract_dir = params[:extract_dir]
      @worker = params[:worker]
    end

    def init_ingest_params(params)
      @dest_path = params[:dest_path]
      @depositor = params[:depositor]
      @collection = params[:collection]
      @ingest_manifest = params[:ingest_manifest]
    end

    def init_log_params(params)
      @log = params[:log]
      @log_identifier = params[:log_identifier]
      @log_report_to_jira = params[:log_report_to_jira]
      @log_status = params[:log_status]
      @log_timestamp = params[:log_timestamp]
    end

    def collection_s3_prefix
      "#{depositor}/#{collection}"
    end

    def to_hash
      {
        agent: agent, platform: platform,
        type: type, ingest_id: ingest_id,
        dest_path: dest_path, depositor: depositor,
        collection: collection, ingest_manifest: ingest_manifest,
        ticket_id: ticket_id, package: package, steward: steward,
        extract_dir: extract_dir, worker: worker
      }.compact
    end

    def to_json(_opts = nil)
      JSON.generate(to_hash)
    end

    def to_pretty_json(_opts = nil)
      JSON.pretty_generate(to_hash)
    end

    def to_hash_ingest
      to_hash
    end

    # Just an alias
    def to_json_ingest
      to_json
    end

    # Just an alias
    def to_pretty_json_ingest(_opts = nil)
      to_pretty_json
    end

    def to_hash_log
      {
        agent: agent, platform: platform,
        type: type, ingest_id: ingest_id,
        ticket_id: ticket_id, log: log,
        log_identifier: log_identifier,
        log_report_to_jira: log_report_to_jira,
        log_status: log_status,
        log_timestamp: log_timestamp
      }.compact
    end

    def to_json_log
      JSON.generate(to_hash_log)
    end

    def to_pretty_json_log(_opts = nil)
      JSON.pretty_generate(to_hash_log)
    end
  end
end
