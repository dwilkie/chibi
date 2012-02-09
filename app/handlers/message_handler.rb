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

  def active_chat
    @active_chat ||= user.active_chat
  end

  def chat_partner
    @chat_partner ||= active_chat.partner(user)
  end

  def locale(user = nil)
    user ||= self.user
    user.locale
  end

  def user_wants_to_logout?
    body.strip.downcase == "stop"
  end

  def logout_user
    user.logout!(:notify => true, :notify_chat_partner => true)
  end

  def start_new_chat
    if user.currently_chatting?
      old_chat_partners_screen_id = chat_partner.screen_id
      deactivate_chat
    end

    introduce_participants(create_new_chat, old_chat_partners_screen_id)
  end

  def introduce_participants(new_chat, old_chat_partners_screen_id = nil)
    if new_chat
      new_chat.introduce_participants(:old_friends_screen_name => old_chat_partners_screen_id)
    else
      user.replies.build.explain_chat_could_not_be_started
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

  def deactivate_chat
    active_chat.deactivate!(:notify => chat_partner)
    @active_chat = nil
    @chat_partner = nil
  end

  def create_new_chat
    # create a new chat
    chat = Chat.new

    # associate the message with the new chat
    message.chat = chat

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
