class MessageHandler
  include Conversational::Conversation
  class_suffix "Handler"

  attr_accessor :user, :topic, :body

  def process!(mo_message)
    self.user = mo_message.user
    self.body = mo_message.body
    self.topic = user.state
    details.process!
  end

  protected

  def reply(text)
    user.mt_messages.create(:body => text)
  end

end

