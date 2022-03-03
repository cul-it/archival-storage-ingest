# frozen_string_literal: true

require 'archival_storage_ingest/ingest_utils/ingest_utils'
require 'archival_storage_ingest/messages/ingest_message'

module TicketHandler
  # This log tracker sends ingest message to log queue to be handled by LogWorker
  # Used by everyone except LogWorker
  class LogTracker
    attr_reader :queue, :worker, :platform

    def initialize(queue:, worker:, platform:)
      @queue = queue
      @worker = worker
      @platform = platform
    end

    def notify_worker_started(ingest_msg:, params:)
      params[:log_status] = 'Started'
      notify_status(ingest_msg: ingest_msg, params: params)
    end

    def notify_worker_completed(ingest_msg:, params:)
      params[:log_status] = 'Completed'
      notify_status(ingest_msg: ingest_msg, params: params)
    end

    def notify_worker_skipped(ingest_msg:, params:)
      params[:log_status] = 'Skipped'
      notify_status(ingest_msg: ingest_msg, params: params)
    end

    def notify_worker_error(ingest_msg:, params:)
      params[:log_status] = 'Error'
      # status = "Error\n\n#{error_msg}"
      notify_status(ingest_msg: ingest_msg, params: params)
    end

    def notify_status(ingest_msg:, params:)
      # ingest_msg.log = status
      # ingest_msg.worker = worker
      # log: params[:log], log_identifier: params[:log_identifier],
      #       log_report_to_jira: params[:log_report_to_jira], log_status: params[:log_status],
      #       log_timestamp: params[:log_timestamp],
      # params = {log_status: status, }
      params[:log_timestamp] = Time.now.utc.iso8601
      log_msg = IngestMessage.log_message(ingest_msg, params)
      queue.send_message(log_msg)
    end

    # This will create a new ticket.
    def notify_error(error_msg)
      ingest_msg = IngestMessage::SQSMessage.new(agent: IngestUtils.agent, ingest_id: SecureRandom.uuid,  worker: worker)
      params = { log: error_msg, log_identifier: worker, log_report_to_jira: true, log_status: 'Error' }
      # queue.send_message(ingest_msg)
      notify_status(ingest_msg: ingest_msg, params: params)
    end
  end

  # This issue tracker updates state of the ticket via initialized ticket handler
  # Used by LogWorker exclusively
  class IssueTracker
    attr_reader :ticket_handler

    def initialize(ticket_handler:)
      @ticket_handler = ticket_handler
    end

    def notify_status(ingest_msg:)
      if ingest_msg.ticket_id.nil?
        notify_error(ingest_msg)
      else
        body = "#{Time.new}\n" \
             "#{ingest_msg.worker}\n" \
             "Depositor/Collection: #{ingest_msg.depositor}/#{ingest_msg.collection}\n" \
             "Ingest ID: #{ingest_msg.ingest_id}\n" \
             "Status: #{ingest_msg.log}"
        ticket_handler.update_issue_tracker(subject: ingest_msg.ticket_id, body: body)
      end
    end

    def notify_error(ingest_msg)
      subject = "#{ingest_msg.worker} service has terminated due to fatal error."
      body = "#{Time.new}\n#{ingest_msg.log}"
      ticket_handler.update_issue_tracker(subject: subject, body: body)
    end
  end

  # this issue tracker leaves no message, used by the ingest manager of the LogWorker in dev mode
  class NoopIssueTracker < LogTracker
    def initialize
      super(queue: '', worker: '')
    end

    def notify_worker_started(ingest_msg); end

    def notify_worker_completed(ingest_msg); end

    def notify_worker_skipped(ingest_msg); end

    def notify_worker_error(ingest_msg:, error_msg:); end

    def notify_error(error_msg); end
  end

  # this issue tracker only reports errors to slack, used by the ingest manager of the LogWorker
  class SlackErrorTracker < NoopIssueTracker
    attr_reader :slack_handler

    def initialize(slack_handler:)
      super()
      @slack_handler = slack_handler
    end

    def notify_worker_error(subject:, error_msg:)
      _notify_error(subject: subject, error_msg: error_msg)
    end

    def notify_error(subject:, error_msg:)
      _notify_error(subject: subject, error_msg: error_msg)
    end

    def _notify_error(subject:, error_msg:)
      slack_handler.update_issue_tracker(subject: subject, body: error_msg)
    end
  end

  # this issue tracker will skip started and skipped messages
  class SuccessIssueTracker < LogTracker
    def notify_worker_started(ingest_msg); end

    def notify_worker_skipped(ingest_msg); end
  end

  # this issue tracker will skip completed and skipped messages
  class StartIssueTracker < IssueTracker
    def notify_worker_completed(ingest_msg); end

    def notify_worker_skipped(ingest_msg); end
  end

  # This issue tracker leaves no message other than completed and error
  # It is to be used by periodic fixity comparator
  # It will notify slack channel for error as well as normal notification
  class PeriodicFixityComparatorTracker < LogTracker
    attr_reader :slack_handler

    def initialize(queue:, worker:, platform:, slack_handler:)
      super(queue: queue, worker: worker, platform: platform)
      @slack_handler = slack_handler
    end

    def notify_worker_started(ingest_msg); end

    def notify_worker_skipped(ingest_msg); end

    def notify_error(error_msg)
      super(error_msg)
      subject = "#{worker} service has terminated due to fatal error."
      slack_handler.update_issue_tracker(subject: subject, body: error_msg)
    end

    def notify_worker_error(ingest_msg:, params:)
      super(ingest_msg: ingest_msg, params: params)
      subject = "#{worker} service has terminated due to fatal error."
      slack_handler.update_issue_tracker(subject: subject, body: error_msg)
    end
  end

  # This issue tracker leaves not message other than error
  # It is to be used by all other periodic fixity worker
  class PeriodicFixityTracker < PeriodicFixityComparatorTracker
    def notify_worker_completed(ingest_msg); end
  end
end
