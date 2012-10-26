# encoding: utf-8

class Message < ActiveRecord::Base
  include Communicable
  include Communicable::FromUser
  include Communicable::Chatable
  include Analyzable

  attr_accessible :body, :guid
  alias_attribute :origin, :from

  has_many :delivery_receipts

  validates :guid, :uniqueness => true, :allow_nil => true

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
      user.update_profile(normalized_body)

      chat_to_forward_message_to = Chat.intended_for(self, :num_recent_chats => 10) || user.active_chat

      if chat_to_forward_message_to.present?
        chat_to_forward_message_to.forward_message(self)
        start_new_chat = false
      end
    end

    introduction = body if introducable?

    Chat.activate_multiple!(
      user, :notify => true, :notify_no_match => false, :introduction => introduction
    ) if start_new_chat
  end

  private

  def user_wants_to_logout?
    normalized_body == "stop"
  end

  def user_wants_to_chat_with_someone_new?
    normalized_body.gsub(/["']/, "") == "new"
  end

  def normalized_body
    @normalized_body ||= body.strip.downcase
  end

  def introducable?
    false
  end
end
