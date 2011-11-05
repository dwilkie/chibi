class MessageHandler
  include Conversational::Conversation
  class_suffix "Handler"

  cattr_accessor :keywords
  attr_accessor :message, :user, :body, :country_code

  def process!(message)
    self.message = message
    self.user = message.user
    self.body = message.body
    self.topic = user.currently_chatting? ? "chat" : "search"
    self.country_code = Location.country_code(user.mobile_number)
    details.process!
  end

  protected

  def reply(text, user = nil)
    user ||= self.user
    reply = Reply.new
    reply.user = user
    reply.body = text
    reply.to = user.mobile_number
    reply.save!
  end

  def keywords(*keys)
    all_keywords = []
    keys.each do |key|
      english_keywords = self.class.keywords["en"][key.to_s]
      localized_keywords = self.class.keywords.try(:[], country_code.downcase).try(:[], key.to_s)
      all_keywords |= localized_keywords.present? ? (english_keywords | localized_keywords) : english_keywords
    end
   "(#{all_keywords.join('|')})"

  end

  def contains_command?(command)
    body =~ /\b#{self.class.commands[command].join("\\b|\\b")}\b/
  end
end

