class Reply < ActiveRecord::Base
  before_validation :set_destination, :on => :create

  include Chibi::Communicable
  include Chibi::Communicable::Chatable
  include Chibi::Analyzable
  include Chibi::Twilio::ApiHelpers

  include AASM

  DELIVERED = "delivered"
  FAILED = "failed"
  CONFIRMED = "confirmed"
  ERROR = "error"
  EXPIRED = "expired"

  NUM_CONSECUTIVE_FAILED_REPLIES_TO_BE_CONSIDERED_AN_INACTIVE_NUMBER = 5

  NUNTIUM_DELIVERED = DELIVERED
  NUNTIUM_FAILED = FAILED
  NUNTIUM_CONFIRMED = CONFIRMED

  TWILIO_DELIVERED = DELIVERED
  TWILIO_FAILED = FAILED
  TWILIO_UNDELIVERED = "undelivered"
  TWILIO_SENT = "sent"
  TWILIO_CHANNEL = "twilio"

  SMSC_ENROUTE       = "ENROUTE"
  SMSC_DELIVERED     = "DELIVERED"
  SMSC_EXPIRED       = "EXPIRED"
  SMSC_DELETED       = "DELETED"
  SMSC_UNDELIVERABLE = "UNDELIVERABLE"
  SMSC_ACCEPTED      = "ACCEPTED"
  SMSC_UNKNOWN       = "UNKNOWN"
  SMSC_REJECTED      = "REJECTED"
  SMSC_INVALID       = "INVALID"

  DELIVERY_CHANNEL_NUNTIUM = "nuntium"
  DELIVERY_CHANNEL_TWILIO = TWILIO_CHANNEL
  DELIVERY_CHANNEL_SMSC = "smsc"

  DELIVERY_CHANNELS = [DELIVERY_CHANNEL_NUNTIUM, DELIVERY_CHANNEL_TWILIO, DELIVERY_CHANNEL_SMSC]

  DELIVERY_STATES = {
    DELIVERY_CHANNEL_NUNTIUM => {
      NUNTIUM_DELIVERED => DELIVERED,
      NUNTIUM_CONFIRMED => CONFIRMED,
      NUNTIUM_FAILED    => FAILED
    },
    DELIVERY_CHANNEL_TWILIO => {
      TWILIO_SENT        => DELIVERED,
      TWILIO_DELIVERED   => CONFIRMED,
      TWILIO_UNDELIVERED => FAILED,
      TWILIO_FAILED      => ERROR,
    },
    DELIVERY_CHANNEL_SMSC => {
      SMSC_ENROUTE       => DELIVERED,
      SMSC_ACCEPTED      => DELIVERED,
      SMSC_DELIVERED     => CONFIRMED,
      SMSC_REJECTED      => FAILED,
      SMSC_UNDELIVERABLE => FAILED,
      SMSC_EXPIRED       => EXPIRED,
      SMSC_DELETED       => ERROR,
      SMSC_UNKNOWN       => ERROR,
      SMSC_INVALID       => ERROR
    }
  }

  validates :to, :body, :presence => true
  validates :token, :uniqueness => true, :allow_nil => true
  validates :delivery_channel, :presence => true,
                               :inclusion => { :in => DELIVERY_CHANNELS }

  alias_attribute :destination, :to

  aasm :column => :state, :whiny_transitions => false do
    state :pending_delivery, :initial => true
    state :queued_for_smsc_delivery
    state :delivered_by_smsc
    state :confirmed
    state :failed
    state :expired
    state :errored

    event :update_delivery_status do
      transitions(
        :from => :pending_delivery,
        :to => :queued_for_smsc_delivery
      )

      transitions(
        :from => :queued_for_smsc_delivery,
        :to   => :delivered_by_smsc,
        :if   => :accepted_by_smsc?
      )

      transitions(
        :from => [:queued_for_smsc_delivery, :delivered_by_smsc],
        :to   => :confirmed,
        :if   => :delivery_confirmed?
      )

      transitions(
        :from => [:queued_for_smsc_delivery, :delivered_by_smsc],
        :to   => :failed,
        :if   => :delivery_failed?
      )

      transitions(
        :from => [:queued_for_smsc_delivery, :delivered_by_smsc],
        :to   => :expired,
        :if   => :delivery_expired?
      )

      transitions(
        :from => [:queued_for_smsc_delivery, :delivered_by_smsc],
        :to   => :errored,
        :if   => :delivery_error?
      )
    end
  end

  def self.delivered
    where("delivered_at IS NOT NULL")
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
    delivered_at.present?
  end

  def forward_message(from, message)
    set_forward_message(from, message)
    save
  end

  def forward_message!(from, message)
    forward_message(from, message)
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

  def not_enough_credit!
    self.body = I18n.t(:not_enough_credit, :locale => user.locale)
    deliver!
  end

  def send_reminder!
    self.body = user.gay? ? canned_reply(:recipient => user).gay_reminder : random_canned_greeting(:recipient => user)
    prepend_screen_id(Faker::Name.first_name)
    deliver!
  end

  def deliver!
    perform_delivery!(body)
    update_delivery_state(:force => true)
    touch(:delivered_at)
  end

  def update_delivery_state(options = {})
    @delivery_state = options[:state]
    @force_state_update = options[:force]
    update_delivery_status
    save_with_state_check
  end

  def delivered_by_smsc!(smsc_name, smsc_message_id, status)
    raise(
      ArgumentError,
      "Reply ##{id} failed to deliver on SMSC: '#{smsc_name}' (SMSC MESSAGE ID: '#{smsc_message_id}')"
    ) unless status

    self.token = smsc_message_id
    self.update_delivery_state(:state => DELIVERED)
    save!
  end

  def fetch_twilio_message_status!
    twilio_message = twilio_client.account.messages.get(token)
    self.smsc_message_status = twilio_message.status.downcase
    parse_twilio_message_status
    save!
  end

  private

  def parse_twilio_message_status
    if reply_state = DELIVERY_STATES[delivery_channel][smsc_message_status]
      update_delivery_state(:state => reply_state)
    end

    enqueue_twilio_message_status_fetch if !reply_state || reply_state == DELIVERED
  end

  def random_canned_greeting(options = {})
    reply = canned_reply(options)
    rand < (1.0/2) ? reply.greeting : reply.contact_me
  end

  def canned_reply(options = {})
    CannedReply.new(user.locale, options)
  end

  def self.queued_for_smsc_delivery
    where(:state => "queued_for_smsc_delivery").where("token IS NOT NULL")
  end

  def undeliver!
    self.delivered_at = nil
    save!
  end

  def save_with_state_check
    if @force_state_update
      result = save
    else
      if valid?
        state_attribute = :state
        result = self.class.where(
          self.class.primary_key => id
        ).where(state_attribute => state_was).update_all(state_attribute => state) == 1
      end
    end
    logout_user_if_failed_consecutively
    result
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

  def set_destination
    self.destination ||= user.try(:mobile_number)
  end

  def delivery_expired?
    @delivery_state == EXPIRED
  end

  def delivery_error?
    @delivery_state == ERROR
  end

  def delivery_failed?
    @delivery_state == FAILED
  end

  def delivery_confirmed?
    @delivery_state == CONFIRMED
  end

  def accepted_by_smsc?
    @delivery_state == DELIVERED
  end

  def logout_user_if_failed_consecutively
    return unless failed?
    number_inactive = true
    recent_replies = user.replies.reverse_order.limit(NUM_CONSECUTIVE_FAILED_REPLIES_TO_BE_CONSIDERED_AN_INACTIVE_NUMBER).pluck(:state)
    return unless recent_replies.count == NUM_CONSECUTIVE_FAILED_REPLIES_TO_BE_CONSIDERED_AN_INACTIVE_NUMBER
    recent_replies.each do |reply_state|
      number_inactive &&= (reply_state == "failed" || reply_state == "rejected")
      break unless number_inactive
    end
    user.logout! if number_inactive
  end

  def torasup_number
    @torasup_number ||= Torasup::PhoneNumber.new(destination)
  end

  def operator
    torasup_number.operator
  end

  def perform_delivery!(message)
    save! if new_record? # ensure message is saved so we don't get a blank destination

    self.operator_name = operator.id

    if deliver_via_nuntium?
      perform_delivery_via_nuntium!(message)
    else
      can_perform_delivery_via_smsc? ?
        perform_delivery_via_smsc!(message) :
        perform_delivery_via_twilio!(message)
    end
  end

  def can_perform_delivery_via_smsc?
    operator.smpp_server_id.present?
  end

  def perform_delivery_via_smsc!(message)
    self.delivery_channel = DELIVERY_CHANNEL_SMSC
    MtMessageSenderJob.perform_later(
      id,
      operator.smpp_server_id,
      operator.short_code,
      destination,
      message
    )
  end

  def perform_delivery_via_twilio!(message)
    self.delivery_channel = DELIVERY_CHANNEL_TWILIO
    response = twilio_client.messages.create(
      :from => twilio_outgoing_number(:sms_capable => true),
      :to => twilio_formatted(destination),
      :body => message
    )
    self.token = response.sid
    enqueue_twilio_message_status_fetch
  end

  def enqueue_twilio_message_status_fetch
    TwilioMessageStatusFetcherJob.set(:wait => twilio_message_status_fetcher_delay.seconds).perform_later(id)
  end

  def twilio_message_status_fetcher_delay
    (Rails.application.secrets[:twilio_message_status_fetcher_delay] || 600).to_i
  end

  def perform_delivery_via_nuntium!(message)
    # use an array so Nuntium sends a POST
    response = nuntium.send_ao([{
      :to => "sms://#{destination}",
      :body => message,
      :suggested_channel => operator.nuntium_channel || TWILIO_CHANNEL
    }])
    self.delivery_channel = DELIVERY_CHANNEL_NUNTIUM
    self.token = response["token"]
  end

  def uuid
    @uuid ||= UUID.new
  end

  def deliver_via_nuntium?
    Rails.application.secrets[:deliver_via_nuntium].to_i == 1
  end

  def nuntium
    @nuntium ||= Nuntium.new(
      Rails.application.secrets[:nuntium_url],
      Rails.application.secrets[:nuntium_account],
      Rails.application.secrets[:nuntium_application],
      Rails.application.secrets[:nuntium_password]
    )
  end
end
