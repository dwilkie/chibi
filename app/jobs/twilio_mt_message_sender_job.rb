class TwilioMtMessageSenderJob < ActiveJob::Base
  queue_as(Rails.application.secrets[:twilio_mt_message_sender_queue])

  def perform(reply_id)
    Reply.find(reply_id).deliver_via_twilio!
  end
end
