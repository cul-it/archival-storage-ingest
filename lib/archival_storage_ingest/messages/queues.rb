# frozen_string_literal: true

# constants for queues

module Queues
  QUEUE_INGEST = 'cular_prod_ingest'
  QUEUE_INGEST_IN_PROGRESS = 'cular_prod_ingest_in_progress'
  QUEUE_INGEST_FAILURES = 'cular_prod_ingest_failures'

  QUEUE_LOG = 'cular_prod_log'
  QUEUE_LOG_IN_PROGRESS = 'cular_prod_log_in_progress'
  QUEUE_LOG_FAILURE = 'cular_prod_log_faliure'
  DEV_QUEUE_LOG = 'cular_dev_log'
  DEV_QUEUE_LOG_IN_PROGRESS = 'cular_dev_log_in_progress'
  DEV_QUEUE_LOG_FAILURE = 'cular_dev_log_faliure'

  QUEUE_TRANSFER_S3 = 'cular_prod_transfer_s3'
  QUEUE_TRANSFER_S3_IN_PROGRESS = 'cular_prod_transfer_s3_in_progress'
  QUEUE_TRANSFER_S3_FAILURES = 'cular_prod_transfer_s3_failures'
  QUEUE_TRANSFER_SFS = 'cular_prod_transfer_sfs'
  QUEUE_TRANSFER_SFS_IN_PROGRESS = 'cular_prod_transfer_sfs_in_progress'
  QUEUE_TRANSFER_SFS_FAILURES = 'cular_prod_transfer_sfs_failures'

  QUEUE_INGEST_FIXITY_S3 = 'cular_prod_ingest_fixity_s3'
  QUEUE_INGEST_FIXITY_S3_IN_PROGRESS = 'cular_prod_ingest_fixity_s3_in_progress'
  QUEUE_INGEST_FIXITY_S3_FAILURES = 'cular_prod_ingest_fixity_s3_failures'
  QUEUE_INGEST_FIXITY_SFS = 'cular_prod_ingest_fixity_sfs'
  QUEUE_INGEST_FIXITY_SFS_IN_PROGRESS = 'cular_prod_ingest_fixity_sfs_in_progress'
  QUEUE_INGEST_FIXITY_SFS_FAILURES = 'cular_prod_ingest_fixity_sfs_failures'
  QUEUE_INGEST_FIXITY_COMPARISON = 'cular_prod_ingest_fixity_comparison'
  QUEUE_INGEST_FIXITY_COMPARISON_IN_PROGRESS = 'cular_prod_ingest_fixity_comparison_in_progress'
  QUEUE_INGEST_FIXITY_COMPARISON_FAILURES = 'cular_prod_ingest_fixity_comparison_failures'

  QUEUE_PERIODIC_FIXITY = 'cular_prod_periodic_fixity'
  QUEUE_PERIODIC_FIXITY_IN_PROGRESS = 'cular_prod_periodic_fixity_in_progress'
  QUEUE_PERIODIC_FIXITY_S3 = 'cular_prod_periodic_fixity_s3'
  QUEUE_PERIODIC_FIXITY_S3_IN_PROGRESS = 'cular_prod_periodic_fixity_s3_in_progress'
  QUEUE_PERIODIC_FIXITY_S3_FAILURES = 'cular_prod_periodic_fixity_s3_failures'
  QUEUE_PERIODIC_FIXITY_SFS = 'cular_prod_periodic_fixity_sfs'
  QUEUE_PERIODIC_FIXITY_SFS_IN_PROGRESS = 'cular_prod_periodic_fixity_sfs_in_progress'
  QUEUE_PERIODIC_FIXITY_SFS_FAILURES = 'cular_prod_periodic_fixity_sfs_failures'
  QUEUE_PERIODIC_FIXITY_COMPARISON = 'cular_prod_periodic_fixity_comparison'
  QUEUE_PERIODIC_FIXITY_COMPARISON_IN_PROGRESS = 'cular_prod_periodic_fixity_comparison_in_progress'
  QUEUE_PERIODIC_FIXITY_COMPARISON_FAILURES = 'cular_prod_periodic_fixity_comparison_failures'

  QUEUE_ERROR = 'cular_prod_error'
  QUEUE_COMPLETE = 'cular_prod_done'

  DEV_QUEUE_INGEST = 'cular_dev_ingest'
  DEV_QUEUE_INGEST_IN_PROGRESS = 'cular_dev_ingest_in_progress'
  DEV_QUEUE_INGEST_FAILURES = 'cular_dev_ingest_failures'

  DEV_QUEUE_TRANSFER_S3 = 'cular_dev_transfer_s3'
  DEV_QUEUE_TRANSFER_S3_IN_PROGRESS = 'cular_dev_transfer_s3_in_progress'
  DEV_QUEUE_TRANSFER_S3_FAILURES = 'cular_dev_transfer_s3_failures'
  DEV_QUEUE_TRANSFER_SFS = 'cular_dev_transfer_sfs'
  DEV_QUEUE_TRANSFER_SFS_IN_PROGRESS = 'cular_dev_transfer_sfs_in_progress'
  DEV_QUEUE_TRANSFER_SFS_FAILURES = 'cular_dev_transfer_sfs_failures'

  DEV_QUEUE_INGEST_FIXITY_S3 = 'cular_dev_fixity_s3'
  DEV_QUEUE_INGEST_FIXITY_S3_IN_PROGRESS = 'cular_dev_fixity_s3_in_progress'
  DEV_QUEUE_INGEST_FIXITY_S3_FAILURES = 'cular_dev_fixity_s3_failures'
  DEV_QUEUE_INGEST_FIXITY_SFS = 'cular_dev_fixity_sfs'
  DEV_QUEUE_INGEST_FIXITY_SFS_IN_PROGRESS = 'cular_dev_fixity_sfs_in_progress'
  DEV_QUEUE_INGEST_FIXITY_SFS_FAILURES = 'cular_dev_fixity_sfs_failures'
  DEV_QUEUE_INGEST_FIXITY_COMPARISON = 'cular_dev_comparison'
  DEV_QUEUE_INGEST_FIXITY_COMPARISON_IN_PROGRESS = 'cular_dev_comparison_in_progress'
  DEV_QUEUE_INGEST_FIXITY_COMPARISON_FAILURES = 'cular_dev_comparison_failures'

  DEV_QUEUE_PERIODIC_FIXITY = 'cular_dev_periodic_fixity'
  DEV_QUEUE_PERIODIC_FIXITY_IN_PROGRESS = 'cular_dev_periodic_fixity_in_progress'
  DEV_QUEUE_PERIODIC_FIXITY_S3 = 'cular_dev_periodic_fixity_s3'
  DEV_QUEUE_PERIODIC_FIXITY_S3_IN_PROGRESS = 'cular_dev_periodic_fixity_s3_in_progress'
  DEV_QUEUE_PERIODIC_FIXITY_S3_FAILURES = 'cular_dev_periodic_fixity_s3_failures'
  DEV_QUEUE_PERIODIC_FIXITY_SFS = 'cular_dev_periodic_fixity_sfs'
  DEV_QUEUE_PERIODIC_FIXITY_SFS_IN_PROGRESS = 'cular_dev_periodic_fixity_sfs_in_progress'
  DEV_QUEUE_PERIODIC_FIXITY_SFS_FAILURES = 'cular_dev_periodic_fixity_sfs_failures'
  DEV_QUEUE_PERIODIC_FIXITY_COMPARISON = 'cular_dev_periodic_fixity_comparison'
  DEV_QUEUE_PERIODIC_FIXITY_COMPARISON_IN_PROGRESS = 'cular_dev_periodic_fixity_comparison_in_progress'
  DEV_QUEUE_PERIODIC_FIXITY_COMPARISON_FAILURES = 'cular_dev_periodic_fixity_comparison_failures'

  DEV_QUEUE_ERROR = 'cular_dev_error'
  DEV_QUEUE_COMPLETE = 'cular_dev_done'

  QUEUE_ECOMMONS_INTEGRATION = 'sqs-cular-ecommons-integration-prod'
  QUEUE_ECOMMONS_INTEGRATION_IN_PROGRESS = 'sqs-cular-ecommons-integration-prod-in-progress'
  DEV_QUEUE_ECOMMONS_INTEGRATION = 'sqs-cular-ecommons-integration-dev'
  DEV_QUEUE_ECOMMONS_INTEGRATION_IN_PROGRESS = 'sqs-cular-ecommons-integration-dev-in-progress'

  SANDBOX_QUEUE_INGEST = 'cular_sandbox_ingest'
  SANDBOX_QUEUE_INGEST_IN_PROGRESS = 'cular_sandbox_ingest_in_progress'
  SANDBOX_QUEUE_LOG = 'cular_sandbox_log'
  SANDBOX_QUEUE_LOG_IN_PROGRESS = 'cular_sandbox_log_in_progress'
  SANDBOX_QUEUE_JIRA = 'cular_sandbox_jira.fifo'
  SANDBOX_QUEUE_JIRA_IN_PROGRESS = 'cular_sandbox_jira_in_progress.fifo'
  SANDBOX_QUEUE_TRANSFER_S3 = 'cular_sandbox_transfer_s3'
  SANDBOX_QUEUE_TRANSFER_S3_IN_PROGRESS = 'cular_sandbox_transfer_s3_in_progress'
  SANDBOX_QUEUE_TRANSFER_SFS = 'cular_sandbox_transfer_sfs'
  SANDBOX_QUEUE_TRANSFER_SFS_IN_PROGRESS = 'cular_sandbox_transfer_sfs_in_progress'
  SANDBOX_QUEUE_INGEST_FIXITY_S3 = 'cular_sandbox_fixity_s3'
  SANDBOX_QUEUE_INGEST_FIXITY_S3_IN_PROGRESS = 'cular_sandbox_fixity_s3_in_progress'
  SANDBOX_QUEUE_INGEST_FIXITY_SFS = 'cular_sandbox_fixity_sfs'
  SANDBOX_QUEUE_INGEST_FIXITY_SFS_IN_PROGRESS = 'cular_sandbox_fixity_sfs_in_progress'
  SANDBOX_QUEUE_INGEST_FIXITY_COMPARISON = 'cular_sandbox_comparison'
  SANDBOX_QUEUE_INGEST_FIXITY_COMPARISON_IN_PROGRESS = 'cular_sandbox_comparison_in_progress'
  SANDBOX_QUEUE_ERROR = 'cular_sandbox_error'
  SANDBOX_QUEUE_COMPLETE = 'cular_sandbox_done'

  def self.valid_queue_name?(queue_name)
    const = Queues.constants.find { |q_symbol| Queues.const_get(q_symbol).eql?(queue_name) }
    !const.nil?
  end
end
