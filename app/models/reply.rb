class Reply < ActiveRecord::Base
  before_validation :set_destination, :on => :create
  before_validation :normalize_token
  after_commit :msisdn_discovery_notify

  include Chibi::Communicable::Chatable
  include Chibi::Analyzable
  include Chibi::Twilio::ApiHelpers

  include AASM

  DELIVERED = "delivered"
  FAILED    = "failed"
  CONFIRMED = "confirmed"
  ERROR     = "error"
  EXPIRED   = "expired"
  UNKNOWN   = "unknown"

  TWILIO_DELIVERED = DELIVERED
  TWILIO_FAILED = FAILED
  TWILIO_UNDELIVERED = "undelivered"
  TWILIO_SENT = "sent"

  SMSC_ENROUTE       = "enroute"
  SMSC_DELIVERED     = "delivered"
  SMSC_EXPIRED       = "expired"
  SMSC_DELETED       = "deleted"
  SMSC_UNDELIVERABLE = "undeliverable"
  SMSC_ACCEPTED      = "accepted"
  SMSC_UNKNOWN       = "unknown"
  SMSC_REJECTED      = "rejected"
  SMSC_INVALID       = "invalid"

  DELIVERY_CHANNEL_TWILIO = "twilio"
  DELIVERY_CHANNEL_SMSC = "smsc"

  DELIVERY_CHANNELS = [DELIVERY_CHANNEL_TWILIO, DELIVERY_CHANNEL_SMSC]

  DELIVERY_STATES = {
    DELIVERY_CHANNEL_TWILIO => {
      TWILIO_SENT        => UNKNOWN,
      TWILIO_DELIVERED   => CONFIRMED,
      TWILIO_UNDELIVERED => FAILED,
      TWILIO_FAILED      => ERROR,
    },
    DELIVERY_CHANNEL_SMSC => {
      SMSC_DELIVERED     => CONFIRMED,
      SMSC_REJECTED      => FAILED,
      SMSC_UNDELIVERABLE => FAILED,
      SMSC_EXPIRED       => EXPIRED,
      SMSC_DELETED       => ERROR,
      SMSC_UNKNOWN       => UNKNOWN,
      SMSC_INVALID       => ERROR
    }
  }

  belongs_to :user, :touch => :last_contacted_at
  belongs_to :msisdn_discovery

  validates :to,
            :presence => true,
            :phony_plausible => true

  validates :body, :presence => true

  validates :delivery_channel, :inclusion => { :in => DELIVERY_CHANNELS }, :allow_nil => true

  delegate :mobile_number, :to => :user, :prefix => true, :allow_nil => true
  delegate :notify, :to => :msisdn_discovery, :prefix => true, :allow_nil => true

  alias_attribute :destination, :to

  attr_accessor :smsc_priority

  aasm :column => :state, :whiny_transitions => false do
    state :pending_delivery, :initial => true
    state :queued_for_smsc_delivery
    state :delivered_by_smsc
    state :confirmed
    state :failed
    state :expired
    state :errored
    state :unknown

    event :deliver, :before => :prepare_for_delivery do
      transitions(
        :from   => :pending_delivery,
        :to     => :queued_for_smsc_delivery,
        :after  => :request_delivery!,
        :if     => :can_be_queued_for_smsc_delivery?
      )
    end

    event :delivery_accepted do
      transitions(
        :from => :queued_for_smsc_delivery,
        :to   => :delivered_by_smsc,
        :if   => :delivery_accepted?
      )
    end

    event :delivery_confirmed do
      transitions(
        :from => :delivered_by_smsc,
        :to   => :confirmed,
        :if   => :delivery_confirmed?
      )
    end

    event :delivery_failed do
      transitions(
        :from => :delivered_by_smsc,
        :to   => :failed,
        :if   => :delivery_failed?
      )
    end

    event :delivery_expired do
      transitions(
        :from => :delivered_by_smsc,
        :to   => :expired,
        :if   => :delivery_expired?
      )
    end

    event :delivery_errored do
      transitions(
        :from => :delivered_by_smsc,
        :to   => :errored,
        :if   => :delivery_error?
      )
    end

    event :delivery_unknown do
      transitions(
        :from => :delivered_by_smsc,
        :to   => :unknown,
        :if   => :delivery_unknown?
      )
    end
  end

  def self.token_find!(token)
    where(:token => token.to_s.downcase).first!
  end

  def self.handle_failed!
    to_users_that_cannot_be_contacted.count.each do |user_id, num_failed|
      UserCleanupJob.perform_later(user_id)
    end
  end

  def self.to_users_that_cannot_be_contacted
    failed_to_deliver.joins(
      :user
    ).merge(
      User.online
    ).merge(
      User.without_recent_interaction
    ).select(
      :user_id
    ).group(
      :user_id
    ).having(
      "count(\"#{table_name}\".\"user_id\") > ?",
      failed_replies_cutoff
    )
  end

  def self.failed_replies_cutoff
    (Rails.application.secrets[:failed_replies_cutoff] || 3).to_i
  end

  def self.failed_to_deliver
    where(:state => "failed")
  end

  def self.delivered
    where.not(:delivered_at => nil)
  end

  def self.last_delivered
    delivered.order(:delivered_at).last
  end

  def self.undelivered
    where(:delivered_at => nil).order(:created_at)
  end

  def self.cleanup!
    where.not(:delivered_at => nil).where("updated_at < ?", 1.month.ago).delete_all
  end

  def body
    read_attribute(:body).to_s
  end

  def delivered?
    delivered_at?
  end

  def forward_message(from, message)
    set_forward_message(from, message)
    save
  end

  def forward_message!(from, message, options = {})
    forward_message(from, message)
    self.smsc_priority = options[:smsc_priority] || 10
    deliver!
  end

  def contact_me(from)
    self.body = canned_reply(:recipient => user).contact_me
    prepend_screen_id(from.screen_id)
    save
  end

  def follow_up!(from, options)
    set_forward_message(from, canned_reply(:recipient => user, :sender => from).follow_up(options))
    deliver!
  end

  def introduce!(partner)
    options = {:sender => partner, :recipient => user}
    canned_message = user.gay? && partner.gay? ?
      canned_reply(options).greeting(:gay => true) :
      random_canned_greeting(options)
    set_forward_message(partner, canned_message)
    deliver!
  end

  def broadcast!(options = {})
    self.body = I18n.t(:broadcast, options)
    self.smsc_priority = options[:smsc_priority] || -10
    deliver!
  end

  def not_enough_credit!
    self.body = I18n.t(:not_enough_credit, :locale => user.locale)
    deliver!
  end

  def send_reminder!(options = {})
    self.body = user.gay? ? canned_reply(:recipient => user).gay_reminder : random_canned_greeting(:recipient => user)
    prepend_screen_id(Faker::Name.first_name)
    self.smsc_priority = options[:smsc_priority] || -5
    deliver!
  end

  def delivered_by_smsc!(smsc_name, smsc_message_id, status)
    return request_delivery! unless status
    self.token = smsc_message_id
    update_delivery_state!(DELIVERED)
  end

  def delivered_by_twilio!
    update_delivery_state!(DELIVERED)
  end

  def delivery_status_updated_by_smsc!(smsc_name, status)
    self.smsc_message_status = status.downcase
    parse_smsc_delivery_status!
  end

  def fetch_twilio_message_status!
    twilio_message = twilio_client.account.messages.get(token)
    self.smsc_message_status = twilio_message.status.downcase
    save!
    parse_twilio_delivery_status!
  end

  private

  def update_delivery_state!(status)
    @delivery_state = status

    case @delivery_state

    when DELIVERED
      delivery_accepted!
    when FAILED
      delivery_failed!
    when CONFIRMED
      delivery_confirmed!
    when ERROR
      delivery_errored!
    when EXPIRED
      delivery_expired!
    when UNKNOWN
      delivery_unknown!
    end
  end

  def set_destination
    if self.to ||= user_mobile_number
      self.operator_name ||= operator.id
      self.smpp_server_id ||= operator.smpp_server_id
    end
  end

  def prepare_for_delivery
    return unless save
    self.delivery_channel = can_perform_delivery_via_smsc? ? DELIVERY_CHANNEL_SMSC : DELIVERY_CHANNEL_TWILIO
  end

  def request_delivery!
    perform_delivery!
    touch(:delivered_at)
  end

  def perform_delivery!
    delivery_channel == DELIVERY_CHANNEL_SMSC ? request_delivery_via_smsc! : request_delivery_via_twilio!
  end

  def can_be_queued_for_smsc_delivery?
    persisted? && valid? && delivery_channel?
  end

  def parse_twilio_delivery_status!
    enqueue_twilio_message_status_fetch if !parse_smsc_delivery_status! || delivered_by_smsc?
  end

  def parse_smsc_delivery_status!
    if reply_state = DELIVERY_STATES[delivery_channel][smsc_message_status]
      update_delivery_state!(reply_state)
      reply_state
    end
  end

  def random_canned_greeting(options = {})
    reply = canned_reply(options)
    rand < (1.0/2) ? reply.greeting : reply.contact_me
  end

  def canned_reply(options = {})
    CannedReply.new(user.locale, options)
  end

  def set_forward_message(from, message)
    message.gsub!(/\A#{from.screen_id}\s*\:?\s*/i, "")
    prepend_screen_id(from.screen_id, message)
  end

  def prepend_screen_id(name, message = nil)
    message ||= body
    self.body = message_with_prepended_screen_name(name, message)
  end

  def message_with_prepended_screen_name(name, message)
    "#{name}: #{message}"
  end

  def delivery_expired?
    delivery_status_can_be_updated? && @delivery_state == EXPIRED
  end

  def delivery_error?
    delivery_status_can_be_updated? && @delivery_state == ERROR
  end

  def delivery_failed?
    delivery_status_can_be_updated? && @delivery_state == FAILED
  end

  def delivery_confirmed?
    delivery_status_can_be_updated? && @delivery_state == CONFIRMED
  end

  def delivery_unknown?
    delivery_status_can_be_updated? && @delivery_state == UNKNOWN
  end

  def delivery_accepted?
    token.present? && @delivery_state == DELIVERED
  end

  def delivery_status_can_be_updated?
    smsc_message_status?
  end

  def torasup_number
    @torasup_number ||= Torasup::PhoneNumber.new(destination)
  end

  def operator
    torasup_number.operator
  end

  def can_perform_delivery_via_smsc?
    smpp_server_id?
  end

  def request_delivery_via_smsc!
    MtMessageSenderJob.perform_later(
      id,
      smpp_server_id,
      operator.short_code,
      destination,
      body,
      smsc_priority
    )
  end

  def request_delivery_via_twilio!
    response = twilio_client.messages.create(
      :from => twilio_outgoing_number(:sms_capable => true),
      :to => twilio_formatted(destination),
      :body => body
    )
    self.token = response.sid
    save!
    enqueue_twilio_mt_message_received
    enqueue_twilio_message_status_fetch
  end

  def enqueue_twilio_message_status_fetch
    TwilioMessageStatusFetcherJob.set(:wait => twilio_message_status_fetcher_delay.seconds).perform_later(id)
  end

  def enqueue_twilio_mt_message_received
    TwilioMtMessageReceivedJob.perform_later(id)
  end

  def twilio_message_status_fetcher_delay
    (Rails.application.secrets[:twilio_message_status_fetcher_delay] || 600).to_i
  end

  def normalize_token
    self.token = token.downcase if token? && normalize_token?
  end

  def delivery_channel_twilio?
    delivery_channel == DELIVERY_CHANNEL_TWILIO
  end

  def normalize_token?
    !delivery_channel_twilio?
  end
end
