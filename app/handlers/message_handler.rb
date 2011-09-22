class MessageHandler
  include Conversational::Conversation
  class_suffix "Handler"

  cattr_accessor :commands
  attr_accessor :subscription, :user, :body

  def process!(at_message)
    self.subscription = at_message.subscription
    self.user = subscription.user
    self.body = at_message.body
    self.topic = user.state
    details.process!
  end

  protected

  def reply(text)
    message = subscription.ao_messages.create(:body => text)
    message.deliver!
  end

  def contains_command?(command)
    body =~ /\b#{self.class.commands[command].join("\\b|\\b")}\b/
  end

end

