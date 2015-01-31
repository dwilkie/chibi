class ChargeRequesterJob < ActiveJob::Base
  queue_as :charge_requester_queue
end
