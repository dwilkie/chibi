class Message < ActiveRecord::Base
  include Communicable
  include Communicable::Chatable

  attr_accessible :body
  alias_attribute :origin, :from

  def body
    read_attribute(:body).to_s
  end

  def process!
    if user.first_message?
      user.welcome!
    elsif user_wants_to_logout?
      user.logout!(:notify => true, :notify_chat_partner => true)
      return
    elsif user.update_locale!(normalized_body, :notify => true)
      return
    end

    start_new_chat = true

    if user.currently_chatting?
      unless user_wants_to_chat_with_someone_new?
        active_chat = user.active_chat
        self.chat = active_chat
        save
        active_chat.forward_message(user, body)
        start_new_chat = false
      end
    else
      user.update_profile(normalized_body, :online => true)
    end

    build_chat(:user => user).activate!(:notify => true) if start_new_chat
  end

  private

  def user_wants_to_logout?
    normalized_body == "stop"
  end

  def user_wants_to_chat_with_someone_new?
    normalized_body == "new"
  end

  def normalized_body
    @normalized_body ||= body.strip.downcase
  end
end
