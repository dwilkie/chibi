class PhoneCallProcessorJob < ActiveJob::Base
  queue_as Rails.application.secrets[:phone_call_processor_queue]

  def perform(phone_call_id, call_params, request_url)
    phone_call = PhoneCall.find(phone_call_id)
    phone_call.set_call_params(call_params, request_url)
    phone_call.process!
  end
end
