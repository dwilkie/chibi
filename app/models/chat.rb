class Chat < ActiveRecord::Base
  include Communicable::HasCommunicableResources

  belongs_to :user
  belongs_to :friend, :class_name => 'User'

  has_many :active_users, :class_name => 'User', :foreign_key => "active_chat_id"

  validates :user, :friend, :presence => true

  alias_attribute :initiator, :user

  # a chat with inactivity, is a fully active chat (which has two or more active users) or
  # a partially active chat chat (which has one or more active users)
  # with no activity in the past inactivity_period timeframe
  def self.with_inactivity(options = {})
    inactivity_period = options[:inactivity_period] || 10.minutes

    condition = options[:active] ? "AND" : "OR"
    joins(:user).joins(:friend).where(
      "users.active_chat_id = #{table_name}.id #{condition} friends_chats.active_chat_id = #{table_name}.id"
    ).where("#{table_name}.updated_at < ?", inactivity_period.ago)
  end

  def self.end_inactive(options = {})
    with_inactivity(options).find_each do |chat|
      Resque.enqueue(ChatDeactivator, chat.id, options)
    end
  end

  def self.reactivate_stagnant!
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

  def activate!(options = {})
    self.friend ||= user.match
    active_users << user unless options[:activate_user] == false

    active_users << friend if friend

    if user.currently_chatting?
      current_chat = user.active_chat
      current_partner = current_chat.partner(user) if options[:notify] && options[:notify_previous_partner]
      current_chat.deactivate!(
        :active_user => user, :notify => current_partner, :reactivate_previous_chat => false
      )
    end

    if friend.present?
      save!
      introduce_participants(options) if options[:notify]
    else
      replies.build(
        :user => user
      ).explain_could_not_find_a_friend! if options[:notify] && options[:notify_no_match] != false
    end

    user.search_for_friend!
  end

  def activate(options = {})
    activate!(options)
    active?
  end

  def deactivate!(options = {})
    # reactivate previous chats by default
    options[:reactivate_previous_chat] = true unless options[:reactivate_previous_chat] == false

    # find the user to remain in this chat if any
    if active_user = options[:active_user]
      user_to_remain_in_chat = in_this_chat?(active_user) ? partner(active_user) : (inactive_user || user_with_inactivity)
    end

    # find the users to leave this chat
    users_to_leave_chat = set_active_users(user_to_remain_in_chat)

    # find the users to notify about this change
    users_to_notify = options[:reactivate_previous_chat] ? reactivate_expired_chats(users_to_leave_chat) : users_to_leave_chat

    if options[:activate_new_chats]
      # create new chats for users who have been deactivated from the chat
      users_to_leave_chat.each do |user|
        self.class.activate_multiple!(
          user, :notify => true, :notify_no_match => false
        ) unless user.reload.currently_chatting?
      end
    end

    # notify the users skipping the instructions to update the users profile if
    # they still remain activated in this chat
    if notify = options[:notify]
      notify = in_this_chat?(notify) ? [notify] : users_to_notify

      reply_chat_was_deactivated!(
        *notify, :skip_update_profile_instructions => notify.include?(user_to_remain_in_chat)
      )
    end
  end

  def forward_message(message)
    reference_user = message.user
    chat_partner = partner(reference_user)
    reply_to_chat_partner = replies.build(:user => chat_partner)

    self.messages << message
    message_body = message.body

    if active? || chat_partner.available?
      reactivate!
      reply_to_chat_partner.forward_message!(reference_user, message_body)
    else
      reply_to_chat_partner.forward_message(reference_user, message_body)
      # remove the sender of the message from current chat
      deactivate!
      # start a new chat for the sender of the message
      self.class.activate_multiple!(reference_user.reload, :notify => true, :notify_no_match => false)
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
    # return chats that have undelivered messages and the chat participants
    # are available to chat

    scoped.joins(
      :user, :friend, :replies
    ).participant_available(
      :users
    ).participant_available(
      :friends_chats
    ).where(
      :replies => {:delivered_at => nil}
    ).includes(:replies).readonly(false)
  end

  def self.participant_available(participant)
    scoped.where(
      "#{participant}.active_chat_id IS NULL
      OR #{participant}.active_chat_id = #{table_name}.id
      OR (
        SELECT #{table_name}.id FROM #{table_name} AS #{participant}_active_chat
        INNER JOIN users AS #{participant}_active_chat_user
        ON #{participant}_active_chat_user.id = #{participant}_active_chat.user_id
        INNER JOIN users AS #{participant}_active_chat_friend
        ON #{participant}_active_chat_friend.id = #{participant}_active_chat.friend_id
        WHERE #{participant}_active_chat.id = #{participant}.active_chat_id
        AND (
          CASE WHEN (
            #{participant}_active_chat_user.id = users.id
          )
          THEN (
            #{participant}_active_chat_friend.active_chat_id IS NULL
            OR #{participant}_active_chat_friend.active_chat_id != #{participant}_active_chat.id
            OR #{participant}_active_chat_friend.state = 'offline'
          )
          ELSE (
            #{participant}_active_chat_user.active_chat_id IS NULL
            OR #{participant}_active_chat_user.active_chat_id != #{participant}_active_chat.id
            OR #{participant}_active_chat_user.state = 'offline'
          )
          END
        ) LIMIT 1
      ) IS NOT NULL"
    ).where(
      "#{participant}.state != ?", "offline"
    )
  end

  def self.with_undelivered_messages_for(user)
    with_undelivered_messages.where(:replies => {:user_id => user.id})
  end

  def self.filter_params(params = {})
    super.where(params.slice(:user_id))
  end

  def introduce_participants(options = {})
    users_to_notify = [friend]
    users_to_notify << user if options[:notify_initiator]
    users_to_notify.each do |reference_user|
      replies.build(:user => reference_user).introduce!(
        partner(reference_user), reference_user == user, options[:introduction]
      )
    end
  end

  def reactivate_expired_chats(users)
    users_to_notify = []

    users.each do |user|
      chat_to_reactivate = self.class.with_undelivered_messages_for(user).first
      chat_to_reactivate ? chat_to_reactivate.reactivate! : users_to_notify << user
    end
    users_to_notify
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

  def reply_chat_was_deactivated!(*destination_users)
    options = destination_users.extract_options!
    destination_users.each do |destination_user|
      replies.build(:user => destination_user).end_chat!(partner(destination_user), options)
    end
  end

  def user_with_inactivity
    replies.last_delivered.try(:user)
  end
end
