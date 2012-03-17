class Dialer
  @queue = :dialer_queue

  def self.perform(missed_call_id, callback_url)
    missed_call = MissedCall.find(missed_call_id)
    missed_call.return_call!(callback_url)
  end
end
