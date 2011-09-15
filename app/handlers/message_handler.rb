class MessageHandler
  include Conversational::Conversation
  class_suffix "Handler"

  cattr_accessor :commands
  attr_accessor :user, :body

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

  def contains_command?(command)
    body =~ /\b#{self.class.commands[command].join("\\b|\\b")}\b/
  end

end

