class ChatExpirer
  @queue = :chat_expirer_queue

  def self.perform(options = {})
    Chat.end_inactive(HashWithIndifferentAccess.new(options))
  rescue Resque::TermException
    Resque.enqueue(self, options)
  end
end
