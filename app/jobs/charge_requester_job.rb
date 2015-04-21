class ChargeRequesterJob < ActiveJob::Base
  queue_as Rails.application.secrets[:charge_requester_external_queue]
end
