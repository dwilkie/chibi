class MessageHandler
  include Conversational::Conversation
  class_suffix "Handler"

  cattr_accessor :commands
  attr_accessor :message, :subscription, :user, :body

  def process!(message)
    self.message = message
    self.subscription = message.subscription
    self.user = subscription.user
    self.body = message.body
    self.topic = user.state
    details.process!
  end

  protected

  def reply(text, subscription = nil)
    subscription ||= self.subscription
    message.create_reply(:subscription => subscription, :body => text)
  end

  def contains_command?(command)
    body =~ /\b#{self.class.commands[command].join("\\b|\\b")}\b/
  end
end

