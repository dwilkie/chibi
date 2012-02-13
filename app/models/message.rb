class Message < ActiveRecord::Base
  belongs_to :user
  belongs_to :chat, :touch => true

  validates :user, :presence => true
  validates :from, :presence => true

  attr_accessible :from, :body

  alias_attribute :origin, :from

  def body
    read_attribute(:body).to_s
  end

  def process!
    if user_wants_to_logout?
      user.logout!(:notify => true, :notify_chat_partner => true)
      return
    end

    start_new_chat = true

    if user.currently_chatting?
      unless user_wants_to_chat_with_someone_new?
        user.active_chat.forward_message(user, body)
        start_new_chat = false
      end
    else
      user.update_profile(body, :online => true)
    end

    build_chat(:user => user).activate(:notify => true) if start_new_chat
  end

  private

  def user_wants_to_logout?
    body.strip.downcase == "stop"
  end

  def user_wants_to_chat_with_someone_new?
    body.strip.downcase == "new"
  end
end
