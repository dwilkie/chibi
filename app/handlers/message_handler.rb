class MessageHandler
  include Conversational::Conversation
  class_suffix "Handler"

  attr_accessor :message, :user, :body, :location

  def process!(message)
    self.message = message
    self.user = message.user
    self.location = user.location
    self.body = message.body
    self.topic = user.currently_chatting? ? "chat" : "search"
    details.process!
  end

  protected

  def keywords(*keys)
    all_keywords = []
    keys.each do |key|
      english_keywords = MESSAGE_KEYWORDS["en"][key.to_s]
      localized_keywords = MESSAGE_KEYWORDS.try(:[], location.locale.to_s).try(:[], key.to_s)
      all_keywords |= localized_keywords.present? ? (english_keywords | localized_keywords) : english_keywords
    end
   "(#{all_keywords.join('|')})"
  end
end
