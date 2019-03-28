# frozen_string_literal: true

require 'mail'

module TicketHandler
  DEFAULT_FROM = 'cular-jiramailer@cornell.edu'
  DEFAULT_TO = 'cular-jiramailer@cornell.edu'

  class JiraHandler
    attr_reader :from, :to

    def initialize(from: DEFAULT_FROM, to: DEFAULT_TO)
      @from = from
      @to = to
      Mail.defaults do
        delivery_method :sendmail
      end
    end

    # If an existing ticket id is used for subject, this will add comment.
    # Otherwise, it will create a new ticket.
    def update_issue_tracker(subject:, body:)
      mail = generate_email(subject: subject, body: body)

      mail.deliver
    end

    def generate_email(subject:, body:)
      mail = Mail.new do
        subject subject
        body body
      end
      # Why don't these work on constructor???
      mail.from(from)
      mail.to(to)
      mail
    end
  end
end
