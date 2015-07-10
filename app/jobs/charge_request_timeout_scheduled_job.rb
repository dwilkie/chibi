class ChargeRequestTimeoutScheduledJob < ActiveJob::Base
  queue_as(Rails.application.secrets[:scheduled_queue])

  def perform
    ChargeRequest.timeout!
  end
end
