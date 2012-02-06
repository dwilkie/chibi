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

  def reply(text, user = nil)
    user ||= self.user
    reply = Reply.new
    reply.user = user
    reply.body = text
    reply.to = user.mobile_number
    reply.save
  end

  def locale(user = nil)
    user ||= self.user
    user.locale
  end

  def start_new_chat(old_chat_partners_screen_id = nil)
    introduce_participants(create_new_chat, old_chat_partners_screen_id)
  end

  def introduce_participants(new_chat, old_chat_partners_screen_id = nil)
    if new_chat
      friend = new_chat.friend

      reply_to_user = I18n.t(
        "messages.new_chat_started",
        :users_name => user.name,
        :old_friends_screen_name => old_chat_partners_screen_id,
        :friends_screen_name => friend.screen_id,
        :to_user => true,
        :locale => locale
      )

      reply_to_friend = I18n.t(
        "messages.new_chat_started",
        :users_name => friend.name,
        :friends_screen_name => user.screen_id,
        :to_user => false,
        :locale => locale(friend)
      )

      reply reply_to_user
      reply reply_to_friend, friend
    else
      reply I18n.t(
        "messages.could_not_start_new_chat",
        :users_name => user.name,
        :locale => locale
      )
    end
  end

  def keywords(*keys)
    all_keywords = []
    keys.each do |key|
      english_keywords = MESSAGE_KEYWORDS["en"][key.to_s]
      localized_keywords = MESSAGE_KEYWORDS.try(:[], location.locale.to_s).try(:[], key.to_s)
      all_keywords |= localized_keywords.present? ? (english_keywords | localized_keywords) : english_keywords
    end
   "(#{all_keywords.join('|')})"
  end

  private

  def create_new_chat
    # create a new chat
    chat = Chat.new

    # find a friend for the user
    friend = User.matches(user).first

    # set the user the chat
    chat.user = user
    chat.active_users << user

    # set the friend in the chat (if found)
    chat.friend = friend
    chat.active_users << friend if friend.present?

    # save and return the chat
    chat if chat.save
  end
end
