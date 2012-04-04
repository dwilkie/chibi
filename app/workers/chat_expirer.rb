class ChatExpirer
  @queue = :chat_expirer_queue

  def self.perform
    Chat.end_inactive(:active_user => true, :notify => true)
  end
end
