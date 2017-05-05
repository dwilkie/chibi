class TwilioMessageStatusFetcherJob < ActiveJob::Base
  queue_as(Rails.application.secrets[:twilio_message_status_fetcher_queue])

  attr_accessor :reply

  def perform(reply_id)
    self.reply = Reply.find(reply_id)
    fetch_twilio_message_status!
  end

  private

  def fetch_twilio_message_status!
    twilio_message = twilio_client.fetch_message(reply.token)
    reply.smsc_message_status = twilio_message.status.downcase
    reply.save!
    parse_twilio_delivery_status!
  end

  def parse_twilio_delivery_status!
    reply.enqueue_twilio_message_status_fetch if !reply.parse_smsc_delivery_status! || reply.delivered_by_smsc?
  end

  def twilio_client
    @twilio_client ||= ::TwilioClient.new
  end
end
