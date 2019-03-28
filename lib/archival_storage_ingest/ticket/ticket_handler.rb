# frozen_string_literal: true

require 'mail'

module TicketHandler
  class JiraHandler
    def add_comment(ingest_msg, comment)
      mail = generate_email(ingest_msg, comment)

      mail.delivery_method :sendmail

      mail.deliver
    end

    def generate_email(ingest_msg, comment)
      Mail.new do
        from ingest_msg.mailer
        to ingest_msg.mailer
        subject msg.ticket_id
        body comment
      end
    end
  end
end
