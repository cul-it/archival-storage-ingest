require 'logger'

# Archival storage ingest loggers
module ArchivalStorageIngestLogger
  DEFAULT_LOG_PATH = '/cul/app/archival_storage_ingest/logs/default.log'.freeze

  def self.get_file_logger(config)
    log_path = config['log_path'].nil? ? DEFAULT_LOG_PATH : config['log_path']
    logger = Logger.new(log_path)
    logger.level = config['debug'] == 1 ? Logger::DEBUG : Logger::INFO
    logger
  end
end