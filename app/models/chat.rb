class Chat < ApplicationRecord
  include Chibi::Communicable::HasCommunicableResources
  has_communicable_resources :phone_calls, :messages, :replies

  DEFAULT_PERMANENT_TIMEOUT_MINUTES = 1440
  DEFAULT_PROVISIONAL_TIMEOUT_MINUTES = 10
  DEFAULT_MAX_ONE_SIDED_INTERACTIONS = 3
  DEFAULT_MAX_TO_ACTIVATE = 5
  DEFAULT_CLEANUP_AGE_DAYS = 30

  belongs_to :user
  belongs_to :friend, :class_name => 'User'
  belongs_to :starter, :polymorphic => true

  has_many :active_users, :class_name => 'User', :foreign_key => "active_chat_id"

  validates :user, :friend, :presence => true

  alias_attribute :initiator, :user

  def self.expire!(mode)
    will_timeout(mode).find_each { |chat| ChatExpirerJob.perform_later(chat.id, mode) }
  end

  def self.reinvigorate!
    with_undelivered_messages.find_each do |chat|
      ChatReinvigoratorJob.perform_later(chat.id)
    end
  end

  def self.left_outer_join(join_table, join_column)
    chats = self.arel_table
    chats.join(
      join_table, Arel::Nodes::OuterJoin
    ).on(
      chats[:id].eq(join_table[join_column])
    ).join_sources
  end

  def self.all_active_users
    left_outer_join(User.arel_table, :active_chat_id)
  end

  def self.all_interactions(interacting_class)
    left_outer_join(interacting_class.arel_table, :chat_id)
  end

  def self.cleanup!
    joins(all_interactions(Message)).merge(Message.not_in_a_chat).joins(all_interactions(PhoneCall)).merge(PhoneCall.not_in_a_chat).joins(all_active_users).merge(User.not_currently_chatting).old.delete_all
  end

  def self.activate_multiple!(initiator, options = {})
    limit = options.delete(:limit) || max_to_activate
    initiator.active_chat_deactivate!(:for => initiator, :reactivate_previous_chat => false)
    initiator.matches.limit(limit).each do |partner|
      initialize_and_activate_for_friend!(initiator, partner, options)
    end
  end

  def self.initiated_or_partnered_by(user)
    where(self.arel_table[:user_id].eq(user.id).or(self.arel_table[:friend_id].eq(user.id)))
  end

  def self.old
    where(self.arel_table[:updated_at].lt(cleanup_age.ago))
  end

  def self.latest
    order(:created_at).reverse_order
  end

  def self.intended_for(message)
    sender = message.user
    initiated_or_partnered_by(sender).joins(:replies).merge(Reply.for_user(sender)).merge(Reply.prepended_with(*message.english_words)).merge(Reply.prepended_with(sender.name, :not => true)).latest.limit(self.intended_for_limit).first
  end

  def activate!(options = {})
    self.starter ||= options[:starter]
    self.friend ||= user.match

    if save
      users_to_activate = [friend]
      users_to_activate << user if options[:activate_user] != false
      self.active_users = users_to_activate
      replies.build(:user => friend).introduce!(user) if options[:notify]
      user.search_for_friend!
    end
  end

  def expire!(mode)
    return if (!self.class.permanent_timeout?(mode) && !active?) || !has_inactivity?(mode)

    deactivation_options = {}
    deactivation_options.merge!(
      :for => user_with_most_recent_interaction || user,
      :activate_new_chats => true
    ) if !self.class.permanent_timeout?(mode)

    deactivate!(deactivation_options)
  end

  def deactivate!(options = {})
    return if deactivated?

    if user_to_leave_chat = options[:for]
      users_to_leave_chat = [user_to_leave_chat]
      user_to_remain_in_chat = partner(user_to_leave_chat)
      users_to_remain_in_chat = active_users.include?(user_to_remain_in_chat) ? [user_to_remain_in_chat] : []
    else
      users_to_leave_chat = [user, friend]
      users_to_remain_in_chat = []
    end

    self.active_users = users_to_remain_in_chat

    if options[:reactivate_previous_chat] != false
      users_to_leave_chat.each { |user| reinvigorate_expired!(user) }
    end

    if options[:activate_new_chats]
      # create new chats for users who have been deactivated from the chat
      users_to_leave_chat.each do |user|
        self.class.activate_multiple!(
          user, :notify => true
        ) if user.reload.available? && !user.currently_chatting?
      end
    end
  end

  def forward_message(message)
    sender = message.user
    recipient = partner(sender)
    reply_to_recipient = replies.build(:user => recipient)

    self.messages << message
    message_body = message.body

    chat_deactivation = true

    if active? || recipient.available?
      reactivate!
      reply_to_recipient.forward_message!(sender, message_body)
      chat_deactivation = one_sided?
    else
      reply_to_recipient.forward_message(sender, message_body)
    end

    if chat_deactivation
      self.class.activate_multiple!(sender, :starter => message, :notify => true)
    end
  end

  def reactivate!
    return if active?
    self.active_users = [user, friend]
    replies.undelivered.each { |undelivered_reply| undelivered_reply.deliver! }
  end

  def reinvigorate!
    [user, friend].each do |user_in_chat|
      undelivered_replies = replies.undelivered.for_user(user_in_chat)
      if user_in_chat.available? && !user_in_chat.currently_chatting? && undelivered_replies.any?
        self.active_users << user_in_chat
        undelivered_replies.each { |undelivered_reply| undelivered_reply.deliver! }
      end
    end
  end

  def active?
    active_users.size == 2
  end

  def partner(reference_user)
    user == reference_user ? friend : user
  end

  def active_user
    active_users.count == 1 && active_users.first
  end

  private

  def self.initialize_and_activate_for_friend!(initiator, partner = nil, options = {})
    new(:user => initiator, :friend => partner).activate!({:activate_user => false}.merge(options))
  end

  def self.with_undelivered_messages
    # return chats that have undelivered messages
    joins(:replies => :user).merge(Reply.undelivered).merge(User.online).readonly(false)
  end

  def self.with_undelivered_messages_for(user)
    with_undelivered_messages.merge(User.by_id(user))
  end

  def self.will_timeout(mode)
    scope = joins(:active_users).where(self.arel_table[:updated_at].lt(self.timeout_duration(mode).ago)).uniq
    permanent_timeout?(mode) ? scope : scope.active
  end

  def self.active
    joins(:active_users, :user, :friend).where("users_chats.active_chat_id = chats.id").where("friends_chats.active_chat_id = chats.id")
  end

  def self.timeout_duration(mode)
    permanent_timeout?(mode) ? permanent_timeout_duration : provisional_timeout_duration
  end

  def self.permanent_timeout?(mode)
    mode.to_s == "permanent"
  end

  def self.cleanup_age
    (Rails.application.secrets[:chat_cleanup_age_days] || DEFAULT_CLEANUP_AGE_DAYS).to_i.days
  end

  def self.max_to_activate
    (Rails.application.secrets[:chat_max_to_activate] || DEFAULT_MAX_TO_ACTIVATE).to_i
  end

  def self.max_one_sided_interactions
    (Rails.application.secrets[:chat_max_one_sided_interactions] || DEFAULT_MAX_ONE_SIDED_INTERACTIONS).to_i
  end

  def self.permanent_timeout_duration
    (Rails.application.secrets[:chat_permanent_timeout_minutes] || DEFAULT_PERMANENT_TIMEOUT_MINUTES).to_i.minutes
  end

  def self.provisional_timeout_duration
    (Rails.application.secrets[:chat_provisional_timeout_minutes] || DEFAULT_PROVISIONAL_TIMEOUT_MINUTES).to_i.minutes
  end

  def self.intended_for_limit
    value = Rails.application.secrets[:chat_intended_for_limit]
    value.presence && value.to_i
  end

  def user_with_most_recent_interaction
    last_interaction = messages.last || phone_calls.last
    last_interaction && last_interaction.user
  end

  def deactivated?
    active_users.empty?
  end

  def one_sided?
    limit = self.class.max_one_sided_interactions
    interaction = messages.latest.limit(limit) + phone_calls.latest.limit(limit)
    user_interaction = interaction.sort_by {|e| (e.created_at) }.reverse.map(&:user_id)
    user_interaction.size >= self.class.max_one_sided_interactions && user_interaction.take(self.class.max_one_sided_interactions).uniq.length == 1
  end

  def has_inactivity?(mode)
    updated_at < self.class.timeout_duration(mode).ago
  end

  def reinvigorate_expired!(user)
    chat = self.class.with_undelivered_messages_for(user).first
    chat && chat.reinvigorate!
  end
end
