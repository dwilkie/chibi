class ReplyStateSetter
  @queue = :reply_state_setter_queue

  def self.perform
    DeliveryReceipt.set_reply_states!
  end
end
