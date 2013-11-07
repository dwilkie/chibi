class ChargeRequestUpdater
  extend RetriedJob
  @queue = :charge_request_updater

  def self.perform(charge_request_id, result, reason)
    charge_request = ChargeRequest.find(charge_request_id)
    charge_request.set_result!(result, reason)
  end
end
