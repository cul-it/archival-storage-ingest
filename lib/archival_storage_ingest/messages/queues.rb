# frozen_string_literal: true

# constants for queues

module Queues
  QUEUE_INGEST = 'ingest'
  QUEUE_TRANSFER_S3 = 'transfer_s3'
  QUEUE_TRANSFER_S3_WEST = 'transfer_s3_west'
  QUEUE_TRANSFER_WASABI = 'transfer_wasabi'
  QUEUE_INGEST_FIXITY = 'ingest_fixity'
  QUEUE_INGEST_FIXITY_COMPARISON = 'ingest_fixity_comparison'
  QUEUE_PERIODIC_FIXITY = 'periodic_fixity'
  QUEUE_PERIODIC_FIXITY_COMPARISON = 'periodic_fixity_comparison'
  QUEUE_ERROR = 'error'
  QUEUE_COMPLETE = 'done'

  def self.resolve_queue_name(queue:, stage:)
    "cular_#{stage}_#{queue}"
  end

  def self.resolve_in_progress_queue_name(queue:, stage:)
    "#{resolve_queue_name(queue:, stage:)}_in_progress"
  end

  def self.resolve_failures_queue_name(queue:, stage:)
    "#{resolve_queue_name(queue:, stage:)}_failures"
  end

  # Right now, only the JIRA queue is fifo.
  QUEUE_JIRA = 'jira'
  def self.resolve_fifo_queue_name(queue:, stage:)
    "#{resolve_queue_name(queue:, stage:)}.fifo"
  end

  def self.resolve_fifo_in_progress_queue_name(queue:, stage:)
    "#{resolve_in_progress_queue_name(queue:, stage:)}.fifo"
  end

  def self.resolve_fifo_failures_queue_name(queue:, stage:)
    "#{resolve_failures_queue_name(queue:, stage:)}.fifo"
  end

  def self.valid_queue_name?(queue_name)
    return false unless queue_name

    return false unless queue_name.start_with?('cular_')

    parts = queue_name.split('_', 3)
    return false unless ArchivalStorageIngest.valid_stage?(parts[1])

    const = Queues.constants.find { |q_symbol| Queues.const_get(q_symbol).eql?(parts[2]) }
    !const.nil?
  end

  def self.west?(queue_name)
    queue_name.end_with?('_west')
  end
end
