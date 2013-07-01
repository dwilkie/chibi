# encoding: utf-8

class Message < ActiveRecord::Base
  include Chibi::Communicable
  include Chibi::Communicable::FromUser
  include Chibi::Communicable::Chatable
  include Chibi::Analyzable
  include Chibi::ChatStarter

  alias_attribute :origin, :from

  validates :guid, :uniqueness => true, :allow_nil => true

  state_machine :initial => :received do
    state :processed

    event :process do
      transition(:received => :processed)
    end
  end

  def self.queue_unprocessed(options = {})
    options[:timeout] ||= 30.seconds.ago
    unprocessed = where(
      "state != 'processed'"
    ).where("created_at <= ?", options[:timeout])
    unprocessed.where(:chat_id => nil).find_each do |message|
      message.queue_for_processing!
    end
    unprocessed.where("chat_id IS NOT NULL").find_each do |message|
      message.fire_events(:process)
    end
  end

  def body
    read_attribute(:body).to_s
  end

  def process!
    return if processed? || chat_id.present?
    user.login!

    if user_wants_to_logout?
      user.logout!
    else
      start_new_chat = true

      unless user_wants_to_chat_with_someone_new?
        user.update_profile(normalized_body)

        chat_to_forward_message_to = Chat.intended_for(self, :num_recent_chats => 10) || user.active_chat

        if chat_to_forward_message_to.present?
          chat_to_forward_message_to.forward_message(self)
          start_new_chat = false
        end
      end

      activate_chats! if start_new_chat
    end

    fire_events(:process)
  end

  def queue_for_processing!
    Resque.enqueue(MessageProcessor, id)
  end

  private

  def user_wants_to_logout?
    normalized_body == "stop" || normalized_body == "off" || normalized_body == "stop all"
  end

  def user_wants_to_chat_with_someone_new?
    normalized_body.gsub(/["']/, "") == "new"
  end

  def normalized_body
    @normalized_body ||= body.strip.downcase
  end

  def activate_chats!
    Chat.activate_multiple!(user, :starter => self, :notify => true)
  end
end
