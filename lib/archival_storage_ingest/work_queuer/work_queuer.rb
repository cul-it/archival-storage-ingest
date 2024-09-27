# frozen_string_literal: true

require 'archival_storage_ingest/work_queuer/input_checker'

module WorkQueuer
  class WorkQueuer
    def initialize(confirm: true)
      @configuration = ArchivalStorageIngest.configuration

      @queuer = @configuration.queuer
      @queue_name = @configuration.message_queue_name
      @issue_logger = @configuration.issue_logger
      @develop = @configuration.develop
      @confirm = confirm
    end

    def worker_name; end

    def queue_work(ingest_config)
      input_checker, status = check_input(ingest_config)
      return unless status

      return if work_type_mismatch(ingest_config)

      return unless confirm(ingest_config, input_checker)

      work_msg = put_work_message(ingest_config)

      send_notification(work_msg)
    end

    def check_input(ingest_config)
      input_checker = input_checker_impl
      input_checker.check_input(ingest_config)
      if input_checker.errors.size.positive?
        puts input_checker.errors
        return [input_checker, false]
      end

      [input_checker, true]
    end

    def input_checker_impl; end

    def send_notification(work_msg)
      work_msg.worker = worker_name
      work_msg.log = work_notification_message(work_msg)
      @issue_logger.notify_status(ingest_msg: work_msg, status: work_msg.log)

      work_msg
    end

    def work_notification_message(work_msg)
      "New ingest\nIngest Info\n#{work_msg.to_pretty_json}"
    end

    def put_work_message(ingest_config)
      msg = IngestMessage::SQSMessage.new(
        type: work_type, ticket_id: ingest_config[:ticket_id],
        job_id: ingest_config[:job_id].nil? ? SecureRandom.uuid : ingest_config[:job_id],
        depositor: ingest_config[:depositor], collection: ingest_config[:collection],
        dest_path: ingest_config[:dest_path], ingest_manifest: ingest_config[:ingest_manifest],
        worker: 'Ingest Queuer'
      )
      q_name = ingest_config[:queue_name].nil? ? @queue_name : ingest_config[:queue_name]
      @queuer.put_message(q_name, msg)
      msg
    end

    def work_type; end

    def work_type_mismatch(ingest_config)
      return nil if ingest_config[:type].eql?(work_type)

      puts "Work type mismatch! Executable work type #{work_type}, ingest config: #{ingest_config[:type]}"
      1
    end

    # We want to skip confirm when periodic fixity comparison worker
    # queues next collection upon successful comparison.
    def confirm(ingest_config, input_checker)
      return true unless @confirm

      confirm_work(ingest_config, input_checker)
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

    def work_type
      IngestMessage::TYPE_INGEST
    end

    def worker_name
      'Ingest Queuer'
    end

    def input_checker_impl
      IngestInputChecker.new
    end

    def work_notification_message(work_msg)
      "New ingest\n" \
        "Ingest Info\n#{work_msg.to_pretty_json}"
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

  class M2MIngestQueuer < WorkQueuer
    # alias for better readability
    def queue_ingest(ingest_config)
      queue_work(ingest_config)
    end

    def worker_name
      'M2M Ingest Queuer'
    end

    def work_type
      IngestMessage::TYPE_INGEST
    end

    def input_checker_impl
      IngestInputChecker.new
    end

    def check_input(ingest_config)
      input_checker = input_checker_impl
      input_checker.check_input(ingest_config)
      if input_checker.errors.size.positive?
        send_error_notification(input_checker.errors)
        return [input_checker, false]
      end

      [input_checker, true]
    end

    def work_notification_message(work_msg); end

    def send_error_notification(errors)
      # do something!
    end

    def confirm_work(_ingest_config, _input_checker)
      true
    end
  end

  # NOTE: Disabled because FixityInputChecker relies on SFS
  # class PeriodicFixityQueuer < WorkQueuer
  #   # alias for better readability
  #   def queue_periodic_fixity_check(ingest_config)
  #     queue_work(ingest_config)
  #   end

  #   def worker_name
  #     'Periodic Fixity Queuer'
  #   end

  #   def work_type
  #     IngestMessage::TYPE_PERIODIC_FIXITY
  #   end

  #   def input_checker_impl
  #     FixityInputChecker.new
  #   end

  #   def work_notification_message(work_msg)
  #     "New periodic fixity check queued.\n" \
  #       "Fixity Check Info\n#{work_msg.to_pretty_json}"
  #   end

  #   def confirm_work(ingest_config, _input_checker)
  #     puts "S3 bucket: #{@configuration.s3_bucket}"
  #     puts "Destination Queue: #{@queue_name}"
  #     print_config_settings(ingest_config)
  #     puts 'Queue fixity check? (Y/N)'
  #     'y'.casecmp(gets.chomp).zero?
  #   end
  # end
end
