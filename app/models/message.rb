class Message < ActiveRecord::Base
  include Chibi::Communicable
  include Chibi::Communicable::FromUser
  include Chibi::Communicable::Chatable
  include Chibi::Analyzable
  include Chibi::ChatStarter
  include Chibi::ChargeRequester

  include AASM

  has_many :message_parts

  attr_accessor :pre_process

  alias_attribute :origin, :from

  validates :guid, :uniqueness => true, :allow_nil => true
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

  aasm :column => :state, :whiny_transitions => false do
    state :received, :initial => true
    state :processed
    state :awaiting_charge_result

    event :process, :if => :can_be_processed? do
      transitions(:from => :received, :to => :awaiting_charge_result, :unless => :user_charge!)
      transitions(:from => :received, :to => :processed, :after => :route_to_destination)
      transitions(:from => :awaiting_charge_result, :to => :processed, :after => :examine_charge_result)
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
      message.process!
    end
  end

  def self.from_nuntium?(params)
    nuntium_params(params).any?
  end

  # nuntium
  def self.accept_messages_from_channel?(params)
    enabled_channels = (Rails.application.secrets[:nuntium_messages_enabled_channels]).to_s.downcase.split(";")
    enabled_channels.include?(nuntium_params(params)[:channel].to_s.downcase)
  end

  def self.from_aggregator(params = {})
    from_nuntium?(params) ? from_nuntium(params) : from_twilio(params)
  end

  def self.by_channel(channel_name)
    where(:channel => channel_name.downcase)
  end

  def self.find_csms_message(channel, csms_reference_number, num_parts, from, to)
    return nil if csms_reference_number == 0 || num_parts == 1
    awaiting_parts.by_channel(channel).where(
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
    tmp_message = new(
      params.slice(
        :from, :to, :channel, :number_of_parts, :csms_reference_number
      )
    )

    message = tmp_message.find_csms_message
    message.message_parts.build(params.slice(:body, :sequence_number))
    message
  end

  def find_csms_message
    valid?
    self.class.find_csms_message(channel, csms_reference_number, number_of_parts, from, to) || self
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

  private

  def can_be_processed?
    !awaiting_parts?
  end

  def set_body_from_message_parts
    self.body = (body.presence || body_from_message_parts) unless more_message_parts?
    self.awaiting_parts = more_message_parts?
    message_parts.clear unless multipart?
  end

  def body_from_message_parts
    message_parts.sort_by(&:sequence_number).map(&:body).join
  end

  def more_message_parts?
    message_parts.any? && message_parts.size < number_of_parts
  end

  def multipart?
    number_of_parts.to_i > 1
  end

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
    Rails.application.secrets[:text_new_for_new_chat].to_i == 1 && normalized_body.gsub(/["']/, "") == "new"
  end

  def normalized_body
    @normalized_body ||= body.strip.downcase
  end

  def normalize_channel
    self.channel = channel.downcase if channel?
  end

  def normalize_to
    self.to = Phony.normalize(to) if to?
  end

  def activate_chats!
    Chat.activate_multiple!(user, :starter => self, :notify => true)
  end

  def self.nuntium_params(params)
    params[:message] || {}
  end
  private_class_method :nuntium_params

  def self.from_nuntium(params)
    new(nuntium_params(params).slice(:body, :guid, :from, :to, :channel))
  end
  private_class_method :from_nuntium

  def self.from_twilio(params)
    params.underscorify_keys!
    new(params.slice(:body, :from, :to).merge(:guid => params[:message_sid], :channel => "twilio"))
  end
  private_class_method :from_twilio
end
