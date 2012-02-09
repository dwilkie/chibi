class Chat < ActiveRecord::Base
  belongs_to :user
  belongs_to :friend, :class_name => 'User'

  has_many :active_users, :class_name => 'User', :foreign_key => "active_chat_id"
  has_many :replies

  validates :user, :friend, :presence => true

  alias_attribute :initiator, :user

  # a chat with inactivity, is an active chat with no activity in the past inactivity_period minutes
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

  def deactivate!(options = {})
    active_users.clear

    if options[:notify]
      notify = (options[:notify] == user || options[:notify] == friend) ? [options[:notify]] : [user, friend]
      reply_chat_has_ended(*notify)
    end
  end

  def forward_message(reference_user, message)
    replies.build(:user => partner(reference_user)).forward_message(reference_user.screen_id, message)
  end

  def introduce_participants(options = {})
    [user, friend].each do |reference_user|
      replies.build(:user => reference_user).introduce(partner(reference_user), options)
    end
  end

  def active?
    active_users.any?
  end

  def partner(reference_user)
    user == reference_user ? friend : user
  end

  private

  def reply_chat_has_ended(*destination_users)
    destination_users.each do |destination_user|
      replies.build(:user => destination_user).logout_or_end_chat(:partner => partner(destination_user))
    end
  end
end
