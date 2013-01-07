class Dialer < RetryWorker
  @queue = :dialer_queue

  def self.perform(missed_call_id)
    missed_call = MissedCall.find(missed_call_id)
    missed_call.return_call!
  end
end
