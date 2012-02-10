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
    else
      unless user.currently_chatting?
        #update_user_details
        build_chat(:user => user, :friend => User.matches(user).first).activate(:notify => true)
      end
    end
  end

  private

  def user_wants_to_logout?
    body.strip.downcase == "stop"
  end
end
