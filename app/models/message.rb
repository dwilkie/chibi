# encoding: utf-8

class Message < ActiveRecord::Base
  include Chibi::Communicable
  include Chibi::Communicable::FromUser
  include Chibi::Communicable::Chatable
  include Chibi::Analyzable
  include Chibi::ChatStarter
  include Chibi::ChargeRequester

  attr_accessor :pre_process

  alias_attribute :origin, :from

  validates :guid, :uniqueness => true, :allow_nil => true

  state_machine :initial => :received do

    state :processed, :awaiting_charge_result

    before_transition :received => :processed, :do => :route_to_destination
    before_transition :awaiting_charge_result => :processed, :do => :examine_charge_result

    event :process do
      transition(:received => :awaiting_charge_result, :unless => :user_charge!)
      transition([:received, :awaiting_charge_result] => :processed)
    end
  end

  def self.queue_unprocessed(options = {})
    options[:timeout] ||= 30.seconds.ago
    unprocessed = where.not(
      :state => :processed
    ).where("created_at <= ?", options[:timeout])
    unprocessed.where(:chat_id => nil).find_each do |message|
      message.queue_for_processing!
    end
    unprocessed.where.not(:chat_id => nil).find_each do |message|
      message.fire_events(:process)
    end
  end

  def body
    read_attribute(:body).to_s
  end

  def charge_request_updated!
    queue_for_processing!
  end

  def queue_for_processing!
    Resque.enqueue(MessageProcessor, id)
  end

  private

  def examine_charge_result
    if charge_request && charge_request.failed?
      user.reply_not_enough_credit!
    else
      self.pre_process = true
      route_to_destination
    end
  end

  def route_to_destination
    return true unless pre_process
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

  def user_charge!
    pre_process ? user.charge!(self) : true
  end

  def pre_process
    self.pre_process = false if (processed? || chat_id.present?)
    return @pre_process unless @pre_process.nil?
    if user_wants_to_logout?
      user.logout!
      self.pre_process = false
    else
      user.login!
      self.pre_process = true
    end
  end

  def user_wants_to_logout?
    normalized_body == "stop" || normalized_body == "off" || normalized_body == "stop all"
  end

  def user_wants_to_chat_with_someone_new?
    ENV["TEXT_NEW_FOR_NEW_CHAT"].to_i == 1 && normalized_body.gsub(/["']/, "") == "new"
  end

  def normalized_body
    @normalized_body ||= body.strip.downcase
  end

  def activate_chats!
    Chat.activate_multiple!(user, :starter => self, :notify => true)
  end
end
