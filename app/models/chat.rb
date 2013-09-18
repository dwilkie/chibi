class Chat < ActiveRecord::Base
  include Chibi::Communicable::HasCommunicableResources
  has_communicable_resources :phone_calls, :messages, :replies

  belongs_to :user
  belongs_to :friend, :class_name => 'User'
  belongs_to :starter, :polymorphic => true

  has_many :active_users, :class_name => 'User', :foreign_key => "active_chat_id"

  validates :user, :friend, :presence => true
  validates :friend_id, :uniqueness => {:scope => :user_id}

  alias_attribute :initiator, :user

  def self.end_inactive(options = {})
    with_inactivity(options).find_each do |chat|
      Resque.enqueue(ChatDeactivator, chat.id, options.merge(:with_inactivity => true))
    end
  end

  def self.reinvigorate!
    with_undelivered_messages.find_each do |chat|
      Resque.enqueue(ChatReactivator, chat.id)
    end
  end

  def self.filter_by(params = {})
    super(params).includes(:user, :friend, :active_users)
  end

  def self.activate_multiple!(user, options = {})
    num_new_chats = options[:count] || 5

    # do this at least once in order to deactivate any existing chats
    initialize_and_activate_for_friend!(user, nil, options)
    user.matches.limit(num_new_chats - 1).each do |friend|
      initialize_and_activate_for_friend!(user, friend, options)
    end
  end

  # returns a chat that this message is intended for
  def self.intended_for(message, options = {})
    options[:num_recent_chats] ||= 5

    sender = message.user

    recent_chats = where(
      "\"#{table_name}\".\"user_id\" = ? OR \"#{table_name}\".\"friend_id\" = ?",
      sender.id, sender.id
    ).where(
      "(SELECT \"replies\".\"id\" FROM \"replies\"
      WHERE (\"replies\".\"user_id\" = ?
      AND \"replies\".\"chat_id\" = \"#{table_name}\".\"id\")
      LIMIT 1) IS NOT NULL", sender.id
    ).order("\"#{table_name}\".\"created_at\" DESC").limit(options[:num_recent_chats]).includes(:user, :friend).references(:replies, table_name)

    normalized_message = message.body.downcase
    intended_chat = nil

    recent_chats.each do |chat|
      recent_partner = chat.partner(sender)
      if normalized_message =~ /\b#{recent_partner.screen_id}\b/i
        intended_chat = chat
        break
      end
    end
    intended_chat
  end

  def activate!(options = {})
    self.starter ||= options[:starter]
    self.friend ||= user.match
    active_users << user unless options[:activate_user] == false

    active_users << friend if friend

    if user.currently_chatting?
      user.active_chat.deactivate!(:active_user => user, :reactivate_previous_chat => false)
    end

    if friend.present?
      save!
      replies.build(:user => friend).introduce!(user) if options[:notify]
    end

    user.search_for_friend!
  end

  def activate(options = {})
    activate!(options)
    active?
  end

  def deactivate!(options = {})
    return if options[:with_inactivity] && !has_inactivity?(options)

    # reactivate previous chats by default
    options[:reactivate_previous_chat] = true unless options[:reactivate_previous_chat] == false

    # find the user to remain in this chat if any
    if active_user = options[:active_user]
      user_to_remain_in_chat = in_this_chat?(active_user) ? partner(active_user) : (inactive_user || user_with_inactivity)
    end

    # find the users to leave this chat
    users_to_leave_chat = set_active_users(user_to_remain_in_chat)

    # reactivate expired chats
    reinvigorate_expired_chats(users_to_leave_chat) if options[:reactivate_previous_chat]

    if options[:activate_new_chats]
      # create new chats for users who have been deactivated from the chat
      users_to_leave_chat.each do |user|
        self.class.activate_multiple!(
          user, :notify => true
        ) unless user.reload.currently_chatting?
      end
    end
  end

  def forward_message(message)
    reference_user = message.user
    chat_partner = partner(reference_user)
    reply_to_chat_partner = replies.build(:user => chat_partner)

    self.messages << message
    message_body = message.body

    chat_deactivation = {}

    if active? || chat_partner.available?
      reactivate!
      reply_to_chat_partner.forward_message!(reference_user, message_body)
      one_sided? ? chat_deactivation.merge!(:active_user => reference_user) : chat_deactivation = nil
    else
      reply_to_chat_partner.forward_message(reference_user, message_body)
    end

    if chat_deactivation
      # remove the sender of the message from current chat
      # this can cause a previous chat to be reinvigorated
      deactivate!(chat_deactivation)

      # start a new chat for the sender of the message if they're still available
      self.class.activate_multiple!(
        reference_user, :starter => message, :notify => true
      ) if reference_user.reload.available?(:not_currently_chatting => true)
    end
  end

  def reactivate!
    return if active?

    self.active_users = [user, friend]
    save

    replies.undelivered.each do |undelivered_reply|
      undelivered_reply.deliver!
    end
  end

  def reinvigorate!
    [user, friend].each do |user_in_chat|
      undelivered_replies = replies.undelivered.where(:replies => {:user_id => user_in_chat})
      if user_in_chat.available?(:not_currently_chatting => true) && undelivered_replies.any?
        self.active_users << user_in_chat
        undelivered_replies.each { |undelivered_reply| undelivered_reply.deliver! }
      end
    end
  end

  def active?
    active_users.size >= 2
  end

  def inactive_user
    active_users = self.active_users
    active_users.first if active_users.size == 1
  end

  def partner(reference_user)
    user == reference_user ? friend : user
  end

  private

  def self.initialize_and_activate_for_friend!(user, friend = nil, options = {})
    new(:user => user, :friend => friend).activate!(options.merge(:activate_user => false))
  end

  def self.with_undelivered_messages
    # return chats that have undelivered messages
    joins(:replies => :user).where(:replies => {:delivered_at => nil}).where.not(:users => {:state => :offline}).order(:id).readonly(false)
  end

  def self.with_undelivered_messages_for(user)
    with_undelivered_messages.where(:replies => {:user_id => user.id})
  end

  # a chat with inactivity, is a fully active chat (which has two or more active users) or
  # a partially active chat chat (which has one or more active users)
  # with no activity in the past inactivity_period timeframe
  def self.with_inactivity(options = {})
    condition = options.delete(:all) ? "OR" : "AND"

    joins(:user).joins(:friend).where(
      "users.active_chat_id = #{table_name}.id #{condition} friends_chats.active_chat_id = #{table_name}.id"
    ).where("#{table_name}.updated_at < ?", inactive_timestamp(options))
  end

  def self.filter_params(params = {})
    super.where(params.slice(:user_id))
  end

  def self.inactive_timestamp(options = {})
    (options[:inactivity_period] || 10.minutes).ago
  end

  def one_sided?(num_messages = 3)
    last_messages = messages.order("created_at DESC").limit(num_messages).pluck(:user_id)
    last_messages.uniq == [last_messages.first] if last_messages.count >= num_messages
  end

  def has_inactivity?(options = {})
    updated_at < self.class.inactive_timestamp(options)
  end

  def reinvigorate_expired_chats(users)
    users.each do |user|
      self.class.with_undelivered_messages_for(user).each do |chat_to_reinvigorate|
        chat_to_reinvigorate.reinvigorate!
      end
    end
  end

  def in_this_chat?(reference_user)
    reference_user == user || reference_user == friend
  end

  def set_active_users(user_to_remain_in_chat = nil)
    if user_to_remain_in_chat && user_to_remain_in_chat.active_chat == self
      self.active_users = [user_to_remain_in_chat]
      users_to_leave_chat = [partner(user_to_remain_in_chat)]
    else
      active_users.clear
      users_to_leave_chat = [user, friend]
    end
    users_to_leave_chat
  end

  def user_with_inactivity
    replies.last_delivered.try(:user)
  end
end
