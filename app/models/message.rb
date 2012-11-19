# encoding: utf-8

class Message < ActiveRecord::Base
  include Communicable
  include Communicable::FromUser
  include Communicable::Chatable
  include Analyzable

  attr_accessible :body, :guid
  alias_attribute :origin, :from

  validates :guid, :uniqueness => true, :allow_nil => true

  state_machine :initial => :received do
    state :queued_for_processing, :processed

    event :queue_for_processing do
      transition(:received => :queued_for_processing)
    end

    event :process do
      transition(:queued_for_processing => :processed)
    end
  end

  def self.queue_unprocessed(options = {})
    options[:timeout] ||= 30.seconds.ago
    scoped.where(
      :state => "received"
    ).where("created_at <= ?", options[:timeout]).find_each do |message|
      message.queue_for_processing!
    end
  end

  def body
    read_attribute(:body).to_s
  end

  def process!
    puts "about to process"
    fire_events(:process)
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

  def queue_for_processing!
    Resque.enqueue(MessageProcessor, id)
    #fire_events(:queue_for_processing)
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
