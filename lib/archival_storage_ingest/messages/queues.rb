# frozen_string_literal: true

# constants for queues

module Queues
  QUEUE_INGEST = 'cular_ingest'
  QUEUE_INGEST_IN_PROGRESS = 'cular_ingest_in_progress'
  QUEUE_INGEST_FAILURES = 'cular_ingest_failures'

  QUEUE_LOG = 'cular_log'
  QUEUE_LOG_IN_PROGRESS = 'cular_log_in_progress'
  QUEUE_LOG_FAILURE = 'cular_log_faliure'
  DEV_QUEUE_LOG = 'cular_development_log'
  DEV_QUEUE_LOG_IN_PROGRESS = 'cular_development_log_in_progress'
  DEV_QUEUE_LOG_FAILURE = 'cular_development_log_faliure'

  QUEUE_TRANSFER_S3 = 'cular_transfer_s3'
  QUEUE_TRANSFER_S3_IN_PROGRESS = 'cular_transfer_s3_in_progress'
  QUEUE_TRANSFER_S3_FAILURES = 'cular_transfer_s3_failures'
  QUEUE_TRANSFER_SFS = 'cular_transfer_sfs'
  QUEUE_TRANSFER_SFS_IN_PROGRESS = 'cular_transfer_sfs_in_progress'
  QUEUE_TRANSFER_SFS_FAILURES = 'cular_transfer_sfs_failures'

  QUEUE_INGEST_FIXITY_S3 = 'cular_ingest_fixity_s3'
  QUEUE_INGEST_FIXITY_S3_IN_PROGRESS = 'cular_ingest_fixity_s3_in_progress'
  QUEUE_INGEST_FIXITY_S3_FAILURES = 'cular_ingest_fixity_s3_failures'
  QUEUE_INGEST_FIXITY_SFS = 'cular_ingest_fixity_sfs'
  QUEUE_INGEST_FIXITY_SFS_IN_PROGRESS = 'cular_ingest_fixity_sfs_in_progress'
  QUEUE_INGEST_FIXITY_SFS_FAILURES = 'cular_ingest_fixity_sfs_failures'
  QUEUE_INGEST_FIXITY_COMPARISON = 'cular_ingest_fixity_comparison'
  QUEUE_INGEST_FIXITY_COMPARISON_IN_PROGRESS = 'cular_ingest_fixity_comparison_in_progress'
  QUEUE_INGEST_FIXITY_COMPARISON_FAILURES = 'cular_ingest_fixity_comparison_failures'

  QUEUE_PERIODIC_FIXITY = 'cular_periodic_fixity'
  QUEUE_PERIODIC_FIXITY_IN_PROGRESS = 'cular_periodic_fixity_in_progress'
  QUEUE_PERIODIC_FIXITY_S3 = 'cular_periodic_fixity_s3'
  QUEUE_PERIODIC_FIXITY_S3_IN_PROGRESS = 'cular_periodic_fixity_s3_in_progress'
  QUEUE_PERIODIC_FIXITY_S3_FAILURES = 'cular_periodic_fixity_s3_failures'
  QUEUE_PERIODIC_FIXITY_SFS = 'cular_periodic_fixity_sfs'
  QUEUE_PERIODIC_FIXITY_SFS_IN_PROGRESS = 'cular_periodic_fixity_sfs_in_progress'
  QUEUE_PERIODIC_FIXITY_SFS_FAILURES = 'cular_periodic_fixity_sfs_failures'
  QUEUE_PERIODIC_FIXITY_COMPARISON = 'cular_periodic_fixity_comparison'
  QUEUE_PERIODIC_FIXITY_COMPARISON_IN_PROGRESS = 'cular_periodic_fixity_comparison_in_progress'
  QUEUE_PERIODIC_FIXITY_COMPARISON_FAILURES = 'cular_periodic_fixity_comparison_failures'

  QUEUE_ERROR = 'cular_error'
  QUEUE_COMPLETE = 'cular_done'

  DEV_QUEUE_INGEST = 'cular_development_ingest'
  DEV_QUEUE_INGEST_IN_PROGRESS = 'cular_development_ingest_in_progress'
  DEV_QUEUE_INGEST_FAILURES = 'cular_development_ingest_failures'

  DEV_QUEUE_TRANSFER_S3 = 'cular_development_transfer_s3'
  DEV_QUEUE_TRANSFER_S3_IN_PROGRESS = 'cular_development_transfer_s3_in_progress'
  DEV_QUEUE_TRANSFER_S3_FAILURES = 'cular_development_transfer_s3_failures'
  DEV_QUEUE_TRANSFER_SFS = 'cular_development_transfer_sfs'
  DEV_QUEUE_TRANSFER_SFS_IN_PROGRESS = 'cular_development_transfer_sfs_in_progress'
  DEV_QUEUE_TRANSFER_SFS_FAILURES = 'cular_development_transfer_sfs_failures'

  DEV_QUEUE_INGEST_FIXITY_S3 = 'cular_development_fixity_s3'
  DEV_QUEUE_INGEST_FIXITY_S3_IN_PROGRESS = 'cular_development_fixity_s3_in_progress'
  DEV_QUEUE_INGEST_FIXITY_S3_FAILURES = 'cular_development_fixity_s3_failures'
  DEV_QUEUE_INGEST_FIXITY_SFS = 'cular_development_fixity_sfs'
  DEV_QUEUE_INGEST_FIXITY_SFS_IN_PROGRESS = 'cular_development_fixity_sfs_in_progress'
  DEV_QUEUE_INGEST_FIXITY_SFS_FAILURES = 'cular_development_fixity_sfs_failures'
  DEV_QUEUE_INGEST_FIXITY_COMPARISON = 'cular_development_comparison'
  DEV_QUEUE_INGEST_FIXITY_COMPARISON_IN_PROGRESS = 'cular_development_comparison_in_progress'
  DEV_QUEUE_INGEST_FIXITY_COMPARISON_FAILURES = 'cular_development_comparison_failures'

  DEV_QUEUE_PERIODIC_FIXITY = 'cular_development_periodic_fixity'
  DEV_QUEUE_PERIODIC_FIXITY_IN_PROGRESS = 'cular_development_periodic_fixity_in_progress'
  DEV_QUEUE_PERIODIC_FIXITY_S3 = 'cular_development_periodic_fixity_s3'
  DEV_QUEUE_PERIODIC_FIXITY_S3_IN_PROGRESS = 'cular_development_periodic_fixity_s3_in_progress'
  DEV_QUEUE_PERIODIC_FIXITY_S3_FAILURES = 'cular_development_periodic_fixity_s3_failures'
  DEV_QUEUE_PERIODIC_FIXITY_SFS = 'cular_development_periodic_fixity_sfs'
  DEV_QUEUE_PERIODIC_FIXITY_SFS_IN_PROGRESS = 'cular_development_periodic_fixity_sfs_in_progress'
  DEV_QUEUE_PERIODIC_FIXITY_SFS_FAILURES = 'cular_development_periodic_fixity_sfs_failures'
  DEV_QUEUE_PERIODIC_FIXITY_COMPARISON = 'cular_development_periodic_fixity_comparison'
  DEV_QUEUE_PERIODIC_FIXITY_COMPARISON_IN_PROGRESS = 'cular_development_periodic_fixity_comparison_in_progress'
  DEV_QUEUE_PERIODIC_FIXITY_COMPARISON_FAILURES = 'cular_development_periodic_fixity_comparison_failures'

  DEV_QUEUE_ERROR = 'cular_development_error'
  DEV_QUEUE_COMPLETE = 'cular_development_done'

  QUEUE_ECOMMONS_INTEGRATION = 'sqs-cular-ecommons-integration-prod'
  QUEUE_ECOMMONS_INTEGRATION_IN_PROGRESS = 'sqs-cular-ecommons-integration-prod-in-progress'
  DEV_QUEUE_ECOMMONS_INTEGRATION = 'sqs-cular-ecommons-integration-dev'
  DEV_QUEUE_ECOMMONS_INTEGRATION_IN_PROGRESS = 'sqs-cular-ecommons-integration-dev-in-progress'

  def self.valid_queue_name?(queue_name)
    const = Queues.constants.find { |q_symbol| Queues.const_get(q_symbol).eql?(queue_name) }
    !const.nil?
  end
end
