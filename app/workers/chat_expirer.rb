class ChatExpirer
  extend RetriedJob
  @queue = :chat_expirer_queue

  def self.perform(options = {})
    Chat.end_inactive(HashWithIndifferentAccess.new(options))
  end
end
