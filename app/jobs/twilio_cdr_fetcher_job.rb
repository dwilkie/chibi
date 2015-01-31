class TwilioCdrFetcherJob < ActiveJob::Base
  queue_as :high

  def perform(phone_call_id)
    phone_call = PhoneCall.find(phone_call_id)
    phone_call.fetch_inbound_twilio_cdr!
    phone_call.fetch_outbound_twilio_cdr!
  end
end
