# frozen_string_literal: true

# constants for queues

module Queues
  QUEUE_INGEST = 'cular_development_ingest'
  QUEUE_TRANSFER_S3 = 'cular_development_transfer_s3'
  QUEUE_TRANSFER_SFS = 'cular_development_transfer_sfs'
  QUEUE_FIXITY_S3 = 'cular_development_fixity_s3'
  QUEUE_FIXITY_SFS = 'cular_development_fixity_sfs'
  QUEUE_FIXITY_COMPARE = 'cular_development_comparison'
  QUEUE_ERROR = 'cular_development_error'
end
