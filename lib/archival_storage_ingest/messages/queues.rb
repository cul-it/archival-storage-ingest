# frozen_string_literal: true

# constants for queues

module Queues
  QUEUE_INGEST = 'cular_development_ingest'
  QUEUE_INGEST_IN_PROGRESS = 'cular_development_ingest_in_progress'
  QUEUE_TRANSFER_S3 = 'cular_development_transfer_s3'
  QUEUE_TRANSFER_S3_IN_PROGRESS = 'cular_development_transfer_s3_in_progress'
  QUEUE_TRANSFER_SFS = 'cular_development_transfer_sfs'
  QUEUE_TRANSFER_SFS_IN_PROGRESS = 'cular_development_transfer_sfs_in_progress'
  QUEUE_FIXITY_S3 = 'cular_development_fixity_s3'
  QUEUE_FIXITY_S3_IN_PROGRESS = 'cular_development_fixity_s3_in_progress'
  QUEUE_FIXITY_SFS = 'cular_development_fixity_sfs'
  QUEUE_FIXITY_SFS_IN_PROGRESS = 'cular_development_fixity_sfs_in_progress'
  QUEUE_FIXITY_COMPARE = 'cular_development_comparison'
  QUEUE_FIXITY_COMPARE_IN_PROGRESS = 'cular_development_comparison_in_progress'
  QUEUE_ERROR = 'cular_development_error'
  QUEUE_COMPLETE = 'cular_development_complete'
end
