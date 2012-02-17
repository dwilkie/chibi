class ChatExpirer
  @queue = :chat_expirer_queue

  def self.perform
    Chat.end_inactive(:notify => true)
  end
end
