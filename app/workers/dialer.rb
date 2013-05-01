class Dialer
  @queue = :dialer_queue

  def self.perform(missed_call_id)
    MissedCall.find(missed_call_id).return_call!
  rescue Resque::TermException
    Resque.enqueue(self, missed_call_id)
  end
end
