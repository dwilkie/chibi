class MessageHandler
  include Conversational::Conversation
  class_suffix "Handler"

  cattr_accessor :commands
  attr_accessor :message, :user, :body

  def process!(message)
    self.message = message
    self.user = message.user
    self.body = message.body
    self.topic = user.state
    details.process!
  end

  protected

  def reply(text, user = nil)
    user ||= self.user
    reply = Reply.new
    reply.user = user
    reply.body = text
    reply.to = user.mobile_number
    reply.save
  end

  def contains_command?(command)
    body =~ /\b#{self.class.commands[command].join("\\b|\\b")}\b/
  end
end

