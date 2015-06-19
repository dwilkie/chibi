class PhoneCallCompletionJob < ActiveJob::Base
  queue_as Rails.application.secrets[:phone_call_completions_queue]

  def perform(params = {})
    PhoneCall.complete!(params)
  end
end
