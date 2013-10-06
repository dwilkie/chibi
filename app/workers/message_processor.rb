class MessageProcessor
  extend RetriedJob
  @queue = :message_processor_queue

  def self.perform(message_id)
    message = Message.find(message_id)
    message.process!
  end
end
