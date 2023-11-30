# frozen_string_literal: true

require 'rspec'
require 'archival_storage_ingest/ticket/ticket_handler'
require 'mail'
require 'mail/network/delivery_methods/test_mailer'

RSpec.describe 'TicketHandler' do
  let(:ticket_id) { 'CULAR-1937' }
  let(:comment) { 'This is a test.' }
  let(:ticket_handler) do
    TicketHandler::JiraHandler.new
  end

  describe 'JiraHandler' do
    it 'generates email object' do
      test_mail = ticket_handler.generate_email(subject: ticket_id, body: comment)
      expect(test_mail.from).to eq([TicketHandler::DEFAULT_FROM])
      expect(test_mail.to).to eq([TicketHandler::DEFAULT_TO])
      expect(test_mail.subject).to eq(ticket_id)
      expect(test_mail.body.to_s).to eq(comment)
    end

    it 'sends email to add comment' do
      # Instantiate this lazy variable so next defaults section actually takes effect!
      ticket_handler

      Mail.defaults do
        delivery_method :test
      end
      Mail::TestMailer.deliveries.clear

      ticket_handler.update_issue_tracker(subject: ticket_id, body: comment)

      expect(Mail::TestMailer.deliveries.length).to eq(1)
      test_mail = Mail::TestMailer.deliveries.first
      expect(test_mail.from).to eq([TicketHandler::DEFAULT_FROM])
      expect(test_mail.to).to eq([TicketHandler::DEFAULT_TO])
      expect(test_mail.subject).to eq(ticket_id)
      expect(test_mail.body.to_s).to eq(comment)
    end
  end
end
