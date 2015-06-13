class Message < ActiveRecord::Base
  include Chibi::Communicable::FromUser
  include Chibi::Communicable::Chatable
  include Chibi::Analyzable
  include Chibi::ChatStarter
  include Chibi::ChargeRequester

  include AASM

  DEFAULT_AWAITING_PARTS_TIMEOUT = 300

  has_many :message_parts

  attr_accessor :continue_processing

  alias_attribute :origin, :from

  validates :user, :associated => true, :presence => true
  validates :channel, :presence => true
  validates :csms_reference_number, :presence => true,
                                    :numericality => {
                                      :only_integer => true,
                                      :greater_than_or_equal_to => 0,
                                      :less_than_or_equal_to => 255
                                    }

  validates :number_of_parts, :presence => true,
                                    :numericality => {
                                      :only_integer => true,
                                      :greater_than_or_equal_to => 1,
                                      :less_than_or_equal_to => 255
                                    }

  before_validation :normalize_channel, :normalize_to, :on => :create
  before_validation :set_body_from_message_parts

  delegate :login!, :logout!, :reply_not_enough_credit!, :to => :user

  aasm :column => :state, :whiny_transitions => false do
    state :received, :initial => true
    state :processed
    state :awaiting_charge_result

    event :await_charge_result do
      transitions(:from => :received, :to => :awaiting_charge_result)
    end

    event :process, :before => [:queue_for_cleanup, :stop_awaiting_parts], :if => :can_be_processed? do
      transitions(
        :from => [:received, :awaiting_charge_result],
        :to => :processed,
        :after => :post_process!
      )
    end
  end

  def self.queue_unprocessed_multipart!
    unprocessed_multipart.find_each { |message| message.queue_for_processing! }
  end

  def self.unprocessed_multipart
    received.multipart.where(self.arel_table[:created_at].lt(awaiting_parts_timeout.seconds.ago))
  end

  def self.multipart
    where(self.arel_table[:number_of_parts].gt(1))
  end

  def self.from_aggregator(params = {})
    from_twilio(params)
  end

  def self.by_channel(channel_name)
    where(:channel => channel_name.downcase)
  end

  def self.find_csms_message(id, channel, csms_reference_number, num_parts, from, to)
    return nil if csms_reference_number == 0 || num_parts == 1
    awaiting_parts.where.not(
      :id => id
    ).where(
      :csms_reference_number => csms_reference_number,
      :number_of_parts => num_parts,
      :from => from,
      :to => to
    ).first
  end

  def self.awaiting_parts
    where(:awaiting_parts => true)
  end

  def self.from_smsc(params = {})
    message = new(
      params.slice(
        :from, :to, :channel, :number_of_parts, :csms_reference_number
      )
    )

    message_part = message.message_parts.build(params.slice(:body, :sequence_number))
    message
  end

  def find_csms_message
    self.class.find_csms_message(id, channel, csms_reference_number, number_of_parts, from, to)
  end

  def body
    read_attribute(:body).to_s
  end

  def charge_request_updated!
    queue_for_processing!
  end

  def queue_for_processing!
    MessageProcessorJob.perform_later(id)
  end

  def destroy_invalid_multipart!
    destroy if invalid_multipart?
  end

  def stop_awaiting_parts
    if awaiting_parts_timeout?
      self.number_of_parts = 1
      save!
      queue_for_processing!
    end
  end

  def pre_process!
    wait_for_charge_result = false

    if received?
      do_pre_processing
      wait_for_charge_result = true if continue_processing? && !charge!
    end

    wait_for_charge_result ? await_charge_result! : process!
  end

  private

  def charge!
    user.charge!(self)
  end

  def charge_request_failed?
    charge_request && charge_request.failed?
  end

  def post_process!
    charge_request_failed? ? reply_not_enough_credit! : route_to_destination
  end

  def route_to_destination
    return if !continue_processing?
    start_new_chat = true

    if !user_wants_to_chat_with_someone_new?
      user.update_profile(normalized_body)
      chat_to_forward_message_to = Chat.intended_for(self, :num_recent_chats => 10) || user.active_chat

      if chat_to_forward_message_to.present?
        chat_to_forward_message_to.forward_message(self)
        start_new_chat = false
      end
    end

    activate_chats! if start_new_chat
  end

  def continue_processing?
    continue_processing.nil? || !!continue_processing
  end

  def awaiting_parts_timeout?
    awaiting_parts? && created_at < self.class.awaiting_parts_timeout.seconds.ago
  end

  def queue_for_cleanup
    MessageCleanupJob.perform_later(id) if invalid_multipart?
  end

  def invalid_multipart?
    multipart? && message_parts.empty?
  end

  def can_be_processed?
    !awaiting_parts? && !invalid_multipart?
  end

  def set_body_from_message_parts
    self.body = (body.presence || body_from_message_parts) unless more_message_parts?
    self.awaiting_parts = more_message_parts?
    message_parts.clear if !multipart? && message_parts.select(&:persisted?).empty?
  end

  def body_from_message_parts
    message_parts.sort_by(&:sequence_number).map(&:body).join
  end

  def more_message_parts?
    message_parts.any? && message_parts.size < number_of_parts
  end

  def multipart?
    csms_reference_number.to_i > 0 && number_of_parts.to_i > 1
  end

  def do_pre_processing
    if user_wants_to_logout?
      logout!
      self.continue_processing = false
    else
      login!
    end
  end

  def user_wants_to_logout?
    ["stop", "off", "stop all"].include?(normalized_body)
  end

  def user_wants_to_chat_with_someone_new?
    normalized_body.gsub(/["']/, "") == "new"
  end

  def normalized_body
    @normalized_body ||= body.strip.downcase
  end

  def normalize_channel
    self.channel = channel.to_s.downcase.presence
  end

  def normalize_to
    self.to = Phony.normalize(to) if to?
  end

  def activate_chats!
    Chat.activate_multiple!(user, :starter => self, :notify => true)
  end

  def self.awaiting_parts_timeout
    (Rails.application.secrets[:message_awaiting_parts_timeout] || DEFAULT_AWAITING_PARTS_TIMEOUT).to_i
  end

  def self.from_twilio(params)
    params = params.underscorify_keys
    new(params.slice(:body, :from, :to).merge(:guid => params[:message_sid], :channel => "twilio"))
  end

  private_class_method :from_twilio
end
