class TwilioMtMessageReceivedJob < ActiveJob::Base
  queue_as Rails.application.secrets[:twilio_mt_message_received_queue]

  def perform(reply_id)
    Reply.find(reply_id).delivered_by_twilio!
  end
end
