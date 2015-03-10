class TwilioMessageStatusFetcherJob < ActiveJob::Base
  queue_as Rails.application.secrets[:twilio_message_status_fetcher_queue]

  def perform(reply_id)
    Reply.find(reply_id).fetch_twilio_message_status!
  end
end
