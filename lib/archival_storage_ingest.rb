require 'archival_storage_ingest/version'
require 'archival_storage_ingest/messages/ingest_message'
require 'archival_storage_ingest/messages/poller'
require 'archival_storage_ingest/messages/queuer'
require 'archival_storage_ingest/messages/queues'
require 'archival_storage_ingest/messages/message_processor'
require 'archival_storage_ingest/workers/worker_pool'
require 'archival_storage_ingest/workers/fixity_compare_worker'
require 'archival_storage_ingest/workers/fixity_worker'
require 'archival_storage_ingest/workers/transfer_worker'
require 'yaml'
require 'aws-sdk-sqs'

# Main archival storage ingest server module
module ArchivalStorageIngest
  COMMAND_SERVER_START = 'start'.freeze
  COMMAND_SERVER_STATUS = 'status'.freeze
  COMMAND_SERVER_STOP = 'stop'.freeze

  # Ingest manager to either start the server or queue new ingest.
  class IngestManager
    def initialize
      default_config_path = '/cul/app/ingest/archival_storage/conf/settings.yaml'
      env_config_path = 'archival_storage_ingest_config'
      config_file = ENV[env_config_path]
      if config_file.nil?
        warn "#{env_config_path} env variable is not set, using default config file path #{default_config_path}"
        config_file = default_config_path
      end

      raise "Configuration file #{config_file} does not exist!" if !File.exists?(config_file)

      @config = YAML.load_file(config_file)
      @queuer = Queuer::SQSQueuer.new
    end

    def queue_ingest(ingest_config)
      msg = IngestMessage::SQSMessage.new(
        ingest_id: SecureRandom.uuid,
        type: IngestMessage::TYPE_INGEST
      )
      @queuer.put_message(Queues::QUEUE_INGEST, msg)
    end

    def server(command)
      if command == COMMAND_SERVER_STATUS
        puts 'Status implementation missing.'
        return
      end

      if command == COMMAND_SERVER_START
        puts 'Start implementation needs to be daemon-ized'
        initialize_server()
        # while true
          do_work()
          # sleep(30) # get this value from config
        # end
      else
        puts 'Stop implementation missing'
        # gracefully stop server
      end
    end

    def initialize_server
      sqs = Aws::SQS::Client.new
      subscribed_queues = {}
      @config['subscribed_queues'].each do |queue_name|
        queue_url = sqs.get_queue_url(queue_name: queue_name).queue_url
        subscribed_queues[queue_name] = queue_url
      end

      puts 'Subscribed to the following queues:'
      subscribed_queues.each do |queue_name, queue_url|
        puts "  name: #{queue_name}, url: #{queue_url}"
      end

      @poller = Poller::SQSPoller.new(subscribed_queues)
      @worker_pool = WorkerPool::CWorkerPool.new
      @message_processor = MessageProcessor::SQSMessageProcessor.new(@queuer)
    end

    def do_work
      # process_finished_job()

      # if !@worker_pool.is_available?
      #   # do nothing
      #   return
      # end

      msg = @poller.get_message()
      if msg.nil?
        # do nothing
        puts 'No message received'
        return
      end

      @message_processor.process_message(msg)
    end

    def process_finished_job
      @worker_pool.active.each do |worker|
        if worker.status == false
          ## it worked!
          result = worker.value
          ## do work
        elsif worker.status.nil?
          ## it died unexpectedly
          ## move to error queue
        end
      end
      @worker_pool.clear_inactive_jobs
    end
  end
end
