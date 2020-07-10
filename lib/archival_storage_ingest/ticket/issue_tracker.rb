# frozen_string_literal: true

module TicketHandler
  class IssueTracker
    attr_reader :worker_name, :ticket_handler

    def initialize(worker_name:, ticket_handler:)
      @worker_name = worker_name
      @ticket_handler = ticket_handler
    end

    # These will add a comment to an existing ticket.
    def notify_worker_started(ingest_msg)
      notify_status(ingest_msg: ingest_msg, status: 'Started')
    end

    def notify_worker_completed(ingest_msg)
      notify_status(ingest_msg: ingest_msg, status: 'Completed')
    end

    def notify_worker_skipped(ingest_msg)
      notify_status(ingest_msg: ingest_msg, status: 'Skipped')
    end

    def notify_worker_error(ingest_msg:, error_msg:)
      body = "#{Time.new}\n" \
             "#{worker_name}\n" \
             "Depositor/Collection: #{ingest_msg.depositor}/#{ingest_msg.collection}\n" \
             "Ingest ID: #{ingest_msg.ingest_id}\n" \
             "Status: Error\n\n#{error_msg}"
      ticket_handler.update_issue_tracker(subject: ingest_msg.ticket_id, body: body)
    end

    def notify_status(ingest_msg:, status:)
      body = "#{Time.new}\n" \
             "#{worker_name}\n" \
             "Depositor/Collection: #{ingest_msg.depositor}/#{ingest_msg.collection}\n" \
             "Ingest ID: #{ingest_msg.ingest_id}\n" \
             "Status: #{status}"
      ticket_handler.update_issue_tracker(subject: ingest_msg.ticket_id, body: body)
    end

    # This will create a new ticket.
    def notify_error(error_msg)
      subject = "#{worker_name} service has terminated due to fatal error."
      body = "#{Time.new}\n#{error_msg}"
      ticket_handler.update_issue_tracker(subject: subject, body: body)
    end
  end

  # this issue tracker leaves no message other than error, used for periodic fixity
  class NoopIssueTracker < IssueTracker
    def notify_worker_started(ingest_msg); end

    def notify_worker_completed(ingest_msg); end

    def notify_worker_skipped(ingest_msg); end
  end

  # this issue tracker will skip started and skipped messages
  class SuccessIssueTracker < IssueTracker
    def notify_worker_started(ingest_msg); end

    def notify_worker_skipped(ingest_msg); end
  end

  # this issue tracker will skip completed and skipped messages
  class StartIssueTracker < IssueTracker
    def notify_worker_completed(ingest_msg); end

    def notify_worker_skipped(ingest_msg); end
  end
end
