class ChargeRequestUpdaterJob < ActiveJob::Base
  queue_as :critical

  def perform(charge_request_id, result, responder, reason = nil)
    charge_request = ChargeRequest.where(:id => charge_request_id, :operator => responder).first!
    charge_request.set_result!(result, reason)
  end
end
