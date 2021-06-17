# frozen_string_literal: true

require 'mail'
require 'net/http'

module TicketHandler
  DEFAULT_FROM = 'cular-jiramailer@cornell.edu'
  DEFAULT_TO = 'cular-jiramailer@cornell.edu'

  class BaseTicketHandler
    def update_issue_tracker(_subject:, _body:); end
  end

  class JiraHandler < BaseTicketHandler
    attr_reader :from, :to

    def initialize(from: DEFAULT_FROM, to: DEFAULT_TO)
      super
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

  class SlackHandler < BaseTicketHandler
    attr_reader :web_hook

    def initialize(web_hook:)
      super
      @web_hook = URI(web_hook)
    end

    def update_issue_tracker(subject:, body:)
      req = Net::HTTP::Post.new(web_hook)
      req.set_form_data('payload' => JSON.generate(payload(subject: subject, body: body)))

      res = Net::HTTP.start(uri.hostname, uri.port) do |http|
        http.request(req)
      end

      # Should we raise exception when it fails?
      # case res
      # when Net::HTTPSuccess, Net::HTTPRedirection
      #   # OK
      # else
      #   res.value
      # end
    end

    def payload(subject:, body:)
      {
        'blocks': [
          payload_header(subject: subject),
          payload_body(body: body)
        ]
      }
    end

    def payload_header(subject:)
      {
        'type': 'header',
        'text': {
          'type': 'plain_text',
          'text': subject,
          'emoji': true
        }
      }
    end

    def payload_body(body:)
      {
        'type': 'section',
        'fields': [
          {
            'type': 'plain_text',
            'text': body
          }
        ]
      }
    end
  end
end
