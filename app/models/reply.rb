class Reply < ActiveRecord::Base
  before_validation :set_destination, :on => :create
  before_validation :normalize_token
  after_commit :msisdn_discovery_notify

  include Chibi::Communicable::Chatable
  include Chibi::Analyzable
  include Chibi::Twilio::ApiHelpers

  include AASM

  DEFAULT_MIN_CONSECUTIVE_FAILED = 3
  DEFAULT_CLEANUP_AGE_DAYS = 30
  DEFAULT_QUEUED_TIMEOUT_HOURS = 24

  DELIVERED = "delivered"
  FAILED    = "failed"
  CONFIRMED = "confirmed"
  ERROR     = "error"
  EXPIRED   = "expired"
  UNKNOWN   = "unknown"
  REJECTED  = "rejected"

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

    event :delivery_rejected do
      transitions(
        :from => :queued_for_smsc_delivery,
        :to => :failed
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
      min_consecutive_failed
    )
  end

  def self.failed_to_deliver
    where(self.arel_table[:state].eq("failed").or(self.arel_table[:state].eq("expired")))
  end

  def self.delivered
    where.not(:delivered_at => nil)
  end

  def self.last_delivered
    delivered.order(:delivered_at).last
  end

  def self.undelivered
    where(:delivered_at => nil)
  end

  def self.for_user(user)
    where(:user_id => user.id)
  end

  def self.prepended_with(*names)
    options = names.extract_options!
    where(names.compact.map {|name| query = self.arel_table[:body].matches("#{name.tr('%', '')}:%"); options[:not] ? query.not : query }.reduce(:or))
  end

  def self.with_token
    where.not(:token => nil)
  end

  def self.queued_for_smsc_delivery_too_long
    queued_for_smsc_delivery.where(self.arel_table[:delivered_at].lt(queued_timeout_hours.ago))
  end

  def self.fix_invalid_states!
    queued_for_smsc_delivery.undelivered.update_all("delivered_at = updated_at")
    queued_for_smsc_delivery_too_long.with_token.find_each do |reply|
      reply.send(:update_delivery_state!, DELIVERED)
      reply.send(:parse_smsc_delivery_status!)
    end
  end

  def self.cleanup!
    delivered.where(self.arel_table[:updated_at].lt(cleanup_age_days.ago)).delete_all
  end

  def self.accepted_by_smsc
    delivered.where.not(:state => [:pending_delivery, :queued_for_smsc_delivery])
  end

  def self.not_a_msisdn_discovery
    where(:msisdn_discovery_id => nil)
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
    self.body = random_canned_greeting(options)
    prepend_screen_id(Faker::Name.first_name)
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

  def delivered_by_smsc!(smsc_name, smsc_message_id, successful, error_message = nil)
    self.smsc_message_status = error_message.to_s.downcase.tr(" ", "_").presence

    if successful
      self.token = smsc_message_id
      update_delivery_state!(DELIVERED)
    else
      update_delivery_state!(REJECTED)
    end
  end

  def delivered_by_twilio!
    update_delivery_state!(DELIVERED)
  end

  def delivery_status_updated_by_smsc!(smsc_name, status)
    self.smsc_message_status = status.downcase
    parse_smsc_delivery_status!
  end

  def fetch_twilio_message_status!
    twilio_message = twilio_client.account.messages.get(format_token(token))
    self.smsc_message_status = twilio_message.status.downcase
    save!
    parse_twilio_delivery_status!
  end

  def deliver_via_twilio!
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

  private

  def contact_me_number
    operator.reply_to_number || operator.short_code || twilio_outgoing_number
  end

  def can_call_short_code?
    operator.caller_id.present?
  end

  def self.min_consecutive_failed
    (Rails.application.secrets[:reply_min_consecutive_failed] || DEFAULT_MIN_CONSECUTIVE_FAILED).to_i
  end

  def self.cleanup_age_days
    (Rails.application.secrets[:reply_cleanup_age_days] || DEFAULT_CLEANUP_AGE_DAYS).to_i.days
  end

  def self.queued_timeout_hours
    (Rails.application.secrets[:reply_queued_timeout_hours] || DEFAULT_QUEUED_TIMEOUT_HOURS).to_i.hours
  end

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
    when REJECTED
      delivery_rejected!
    end
  end

  def set_destination
    if self.to ||= user_mobile_number
      self.operator_name ||= operator.id
      self.smpp_server_id ||= operator.smpp_server_id
    end
  end

  def prepare_for_delivery
    return if !save || (user && !user.can_receive_sms?)
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
    CannedReply.new(options.delete(:locale) || user.locale, contact_me_number, can_call_short_code?, options)
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
    @torasup_number ||= Torasup::PhoneNumber.new(destination || user_mobile_number)
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
    enqueue_twilio_mt_message_sender_job
  end

  def enqueue_twilio_message_status_fetch
    TwilioMessageStatusFetcherJob.set(:wait => twilio_message_status_fetcher_delay.seconds).perform_later(id)
  end

  def enqueue_twilio_mt_message_received
    TwilioMtMessageReceivedJob.perform_later(id)
  end

  def enqueue_twilio_mt_message_sender_job
    TwilioMtMessageSenderJob.perform_later(id)
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
