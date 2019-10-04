# frozen_string_literal: true

require 'archival_storage_ingest/work_queuer/input_checker'

module WorkQueuer
  class WorkQueuer
    def initialize
      @configuration = ArchivalStorageIngest.configuration

      @queuer = @configuration.queuer
      @queue_name = @configuration.message_queue_name
      @ticket_handler = @configuration.ticket_handler
      @develop = @configuration.develop
    end

    def queue_work(ingest_config)
      input_checker = input_checker_impl
      input_checker.check_input(ingest_config)
      if input_checker.errors.size.positive?
        puts input_checker.errors
        return
      end

      return unless confirm_work(ingest_config, input_checker)

      work_msg = put_work_message(ingest_config)

      send_notification(work_msg)
    end

    def input_checker_impl; end

    def send_notification(work_msg); end

    def put_work_message(ingest_config)
      msg = IngestMessage::SQSMessage.new(
        ingest_id: SecureRandom.uuid, ticket_id: ingest_config[:ticket_id],
        depositor: ingest_config[:depositor], collection: ingest_config[:collection],
        dest_path: ingest_config[:dest_path],
        ingest_manifest: ingest_config[:ingest_manifest]
      )
      @queuer.put_message(@queue_name, msg)
      msg
    end

    def confirm_work(ingest_config, input_checker); end

    def print_config_settings(ingest_config)
      ingest_config.keys.sort.each do |key|
        puts "#{key}: #{ingest_config[key]}"
      end
    end
  end

  class IngestQueuer < WorkQueuer
    # alias for better readability
    def queue_ingest(ingest_config)
      queue_work(ingest_config)
    end

    def input_checker_impl
      WorkQueuer::IngestInputChecker.new
    end

    def send_notification(work_msg)
      body = "New ingest queued at #{Time.new}.\n" \
             "Depositor/Collection: #{work_msg.depositor}/#{work_msg.collection}\n" \
             "Ingest Info\n#{work_msg.to_pretty_json}"
      @ticket_handler.update_issue_tracker(subject: work_msg.ticket_id, body: body)
    end

    def confirm_work(ingest_config, input_checker)
      puts "S3 bucket: #{@configuration.s3_bucket}"
      puts "Destination Queue: #{@queue_name}"
      print_config_settings(ingest_config)
      puts "Source path: #{input_checker.ingest_manifest.packages[0].source_path}"
      puts 'Queue ingest? (Y/N)'
      'y'.casecmp(gets.chomp).zero?
    end
  end

  class PeriodicFixityQueuer < WorkQueuer
    # alias for better readability
    def queue_periodic_fixity_check(ingest_config)
      queue_work(ingest_config)
    end

    def input_checker_impl
      WorkQueuer::InputChecker.new
    end

    def send_notification(work_msg)
      body = "New fixity check queued for #{Time.new}.\n" \
             "Depositor/Collection: #{work_msg.depositor}/#{work_msg.collection}\n" \
             "Fixity Check Info\n#{work_msg.to_pretty_json}"
      @ticket_handler.update_issue_tracker(subject: work_msg.ticket_id, body: body)
    end

    def confirm_work(ingest_config, _input_checker)
      puts "S3 bucket: #{@configuration.s3_bucket}"
      puts "Destination Queue: #{@queue_name}"
      print_config_settings(ingest_config)
      puts 'Queue fixity check? (Y/N)'
      'y'.casecmp(gets.chomp).zero?
    end
  end
end
