class Dialer
  extend RetriedJob
  @queue = :dialer_queue

  def self.perform(missed_call_id)
    MissedCall.find(missed_call_id).return_call!
  end
end
