# encoding: utf-8

class Message < ActiveRecord::Base
  include Communicable
  include Communicable::Chatable
  include Analyzable

  attr_accessible :body
  alias_attribute :origin, :from

  def body
    read_attribute(:body).to_s
  end

  def process!
    user.login!

    if user_wants_to_logout?
      user.logout!
      return
    elsif user.update_locale!(normalized_body, :notify => true)
      return
    end

    start_new_chat = true

    unless user_wants_to_chat_with_someone_new?
      if user.currently_chatting?
        user.active_chat.forward_message(user, self)
        start_new_chat = false
      else
        user.update_profile(normalized_body)
      end
    end

    Chat.activate_multiple!(user, :notify => true, :notify_no_match => false) if start_new_chat
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
