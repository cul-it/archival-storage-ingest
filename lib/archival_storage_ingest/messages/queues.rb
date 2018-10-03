# constants for queues
module Queues
  QUEUE_INGEST         = 'cular_development_ingest'.freeze
  QUEUE_TRANSFER_S3    = 'cular_development_transfer_s3'.freeze
  QUEUE_TRANSFER_SFS   = 'cular_development_transfer_sfs'.freeze
  QUEUE_FIXITY_S3      = 'cular_development_fixity_s3'.freeze
  QUEUE_FIXITY_SFS     = 'cular_development_fixity_sfs'.freeze
  QUEUE_FIXITY_COMPARE = 'cular_development_comparison'.freeze
  QUEUE_ERROR = 'cular_development_error'.freeze

  TYPE2QUEUE = {
      IngestMessage::TYPE_INGEST => Queues::QUEUE_INGEST,
      IngestMessage::TYPE_TRANSFER_S3 => Queues::QUEUE_TRANSFER_S3,
      IngestMessage::TYPE_TRANSFER_SFS => Queues::QUEUE_TRANSFER_SFS,
      IngestMessage::TYPE_FIXITY_S3 => Queues::QUEUE_FIXITY_S3,
      IngestMessage::TYPE_FIXITY_SFS => Queues::QUEUE_FIXITY_SFS,
      IngestMessage::TYPE_FIXITY_COMPARE => Queues::QUEUE_FIXITY_COMPARE
  }.freeze
end
