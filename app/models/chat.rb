class Chat < ActiveRecord::Base
  belongs_to :user
  belongs_to :friend, :class_name => 'User'

  has_many :active_users, :class_name => 'User', :foreign_key => "active_chat_id"
  has_many :replies

  validates :user, :friend, :presence => true

  def self.with_inactivity(inactivity_period = 10.minutes)
    joins(:user).where(
      "users.active_chat_id = chats.id"
    ).joins(:friend).where(
      "friends_chats.active_chat_id = chats.id"
    ).where("chats.updated_at < ?", inactivity_period.ago)
  end

  def self.end_inactive
    with_inactivity.find_each do |chat|
      chat.deactivate!
    end
  end

  def deactivate!
    active_users.clear
  end

  def active?
    active_users.any?
  end
end
