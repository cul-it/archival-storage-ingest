require 'logger'

# Archival storage ingest loggers
module ArchivalStorageIngestLogger
  DEFAULT_LOG_PATH = '/cul/app/ingest/archival_storage/logs/archival_storage_ingest_activity.log'.freeze

  def self.get_file_logger(config)
    log_path = DEFAULT_LOG_PATH if config['log_path'].nil?
    logger = Logger.new(log_path)
    logger.level = if config['debug'] == 1
                     Logger::DEBUG
                   else
                     Logger::INFO
                   end
    return logger
  end
end