class Chat < ActiveRecord::Base
  belongs_to :user
  belongs_to :friend, :class_name => 'User'

  has_many :active_users, :class_name => 'User', :foreign_key => "active_chat_id"
  has_many :replies

  validates :user, :friend, :presence => true

  alias_attribute :initiator, :user

  # a chat with inactivity, is an active chat with no activity in the past inactivity_period minutes
  def self.with_inactivity(inactivity_period = nil)
    inactivity_period ||= 10.minutes

    joins(:user).where(
      "users.active_chat_id = #{table_name}.id"
    ).joins(:friend).where(
      "friends_chats.active_chat_id = #{table_name}.id"
    ).where("#{table_name}.updated_at < ?", inactivity_period.ago)
  end

  def self.end_inactive(options = {})
    with_inactivity(options.delete(:inactivity_period)).find_each do |chat|
      Resque.enqueue(ChatDeactivator, chat.id, options)
    end
  end

  def self.filter_by(params = {})
    scoped.order("created_at DESC")
  end

  def activate!(options = {})
    self.friend ||= user.match
    active_users << user
    active_users << friend if friend

    if user.currently_chatting?
      current_chat = user.active_chat
      current_partner = current_chat.partner(user) if options[:notify]
      current_chat.deactivate!(:notify => current_partner)
    end

    if friend.present?
      save!
      introduce_participants if options[:notify]
    else
      replies.build(
        :user => user
      ).explain_chat_could_not_be_started! if options[:notify] && options[:notify_no_match] != false
    end
  end

  def activate(options = {})
    activate!(options)
    active?
  end

  def deactivate!(options = {})
    active_user = options[:active_user]

    user_to_remain_in_chat = ((active_user == user || active_user == friend) ? partner(active_user) : user_with_inactivity) if options[:active_user]

    if user_to_remain_in_chat
      self.active_users = [user_to_remain_in_chat]
      users_to_leave_chat = [partner(user_to_remain_in_chat)]
    else
      active_users.clear
      users_to_leave_chat = [user, friend]
    end

    users_to_notify = []

    users_to_leave_chat.each do |user_to_leave_chat|
      chat_to_reactivate = self.class.with_undelivered_messages_for(user_to_leave_chat).first
      chat_to_reactivate ? chat_to_reactivate.reactivate! : users_to_notify << user_to_leave_chat
    end

    if options[:notify]
      notify = (options[:notify] == user || options[:notify] == friend) ? [options[:notify]] : users_to_notify
      reply_chat_has_ended(*notify)
    end
  end

  def forward_message(reference_user, message)
    chat_partner = partner(reference_user)
    reply_to_chat_partner = replies.build(:user => chat_partner)

    if active? || chat_partner.available?
      reactivate!
      reply_to_chat_partner.forward_message!(reference_user.screen_id, message)
    else
      replies.build(:user => reference_user).explain_friend_is_unavailable!(chat_partner)
      reply_to_chat_partner.forward_message(reference_user.screen_id, message)
    end
  end

  def introduce_participants
    [user, friend].each do |reference_user|
      replies.build(:user => reference_user).introduce!(
        partner(reference_user), reference_user == user
      )
    end
  end

  def reactivate!
    touch
    return if active?

    self.active_users = [user, friend]
    save

    replies.undelivered.each do |undelivered_reply|
      undelivered_reply.deliver!
    end
  end

  def active?
    active_users.size >= 2
  end

  def partner(reference_user)
    user == reference_user ? friend : user
  end

  private

  def self.with_undelivered_messages_for(user)
    scoped.includes(:replies).where(:replies => {:delivered_at => nil, :user_id => user.id})
  end

  def reply_chat_has_ended(*destination_users)
    destination_users.each do |destination_user|
      replies.build(:user => destination_user).end_chat!(partner(destination_user))
    end
  end

  def user_with_inactivity
    replies.delivered.order(:created_at).last.try(:user)
  end
end
