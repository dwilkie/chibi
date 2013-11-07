class Reply < ActiveRecord::Base
  before_validation :set_destination, :on => :create

  include Chibi::Communicable
  include Chibi::Communicable::Chatable
  include Chibi::Analyzable

  DELIVERED = "delivered"
  FAILED = "failed"
  CONFIRMED = "confirmed"
  NUM_CONSECUTIVE_FAILED_REPLIES_TO_BE_CONSIDERED_AN_INACTIVE_NUMBER = 5

  TWILIO_CHANNEL = "twilio"

  validates :to, :body, :presence => true
  validates :token, :uniqueness => true, :allow_nil => true

  alias_attribute :destination, :to

  state_machine :initial => :pending_delivery, :action => :save_with_state_check do
    state :pending_delivery,
          :queued_for_smsc_delivery,
          :delivered_by_smsc,
          :rejected,
          :failed,
          :confirmed

    after_transition any => [:failed, :rejected], :do => :logout_user

    event :update_delivery_status do
      transition(
        [
          :pending_delivery,
          :queued_for_smsc_delivery
        ] => :delivered_by_smsc, :if => :delivery_succeeded?
      )

      transition(:pending_delivery         => :queued_for_smsc_delivery)
      transition(:queued_for_smsc_delivery => :rejected,          :if => :delivery_failed?)
      transition(:delivered_by_smsc        => :failed,            :if => :delivery_failed?)
      # the following handles the case where the delivery receipts were received out of order
      transition(:rejected                 => :failed,            :if => :delivery_succeeded?)
      transition(
        [
          :queued_for_smsc_delivery,
          :delivered_by_smsc,
          :rejected,
          :failed
        ] => :confirmed, :if => :delivery_confirmed?
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

  def self.query_queued!
    queued_for_smsc_delivery.where("delivered_at < ?", 10.minutes.ago).where("body IS NOT NULL").find_each do |reply|
      Resque.enqueue(NuntiumAoQueryer, reply.id)
    end
  end

  def self.cleanup!
    where.not(:delivered_at => nil).where("updated_at < ?", 1.month.ago).delete_all
  end

  def self.fix_blank!
    queued_for_smsc_delivery.where(:body => nil).find_each do |reply|
      Resque.enqueue(BlankReplyFixer, reply.id)
    end
  end

  def query_nuntium_ao!
    if token.present? && body.present?
      ao = nuntium.get_ao(token).first
      undeliver! if ao["body"].blank?
      update_delivery_state(:state => ao["state"])
    end
  end

  def fix_blank!
    if body.blank? && chat.present?
      replies = chat.replies.order(:id)
      if message_to_forward = chat.messages.order(:id)[replies.index(self) - 1]
        set_forward_message(message_to_forward.user, message_to_forward.body)
        undeliver!
      end
    end
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
    touch(:delivered_at)
    update_delivery_state
  end

  def update_delivery_state(options = {})
    @delivery_state = options[:state]
    @force_state_update = options[:force]
    update_delivery_status
  end

  private

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
    return save if @force_state_update
    if valid?
      state_attribute = self.class.state_machine.attribute
      self.class.where(
        self.class.primary_key => id
      ).where(state_attribute => state_was).update_all(state_attribute => state) == 1
    end
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

  def delivery_succeeded?
    @delivery_state == DELIVERED
  end

  def delivery_failed?
    @delivery_state == FAILED
  end

  def delivery_confirmed?
    @delivery_state == CONFIRMED
  end

  def logout_user
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

    if deliver_via_nuntium?
      perform_delivery_via_nuntium!(message)
      return save!
    end

    self.token = uuid.generate
    if queue = operator.mt_message_queue
      Resque.enqueue_to(
        queue, MtMessageWorker, token,
        operator.short_code, destination, message
      )
    else
      # queue message on Twilio...
    end
    save!
  end

  def perform_delivery_via_nuntium!(message)
    # use an array so Nuntium sends a POST
    response = nuntium.send_ao([{
      :to => "sms://#{destination}",
      :body => message,
      :suggested_channel => operator.nuntium_channel || TWILIO_CHANNEL
    }])
    self.token = response["token"]
  end

  def uuid
    @uuid ||= UUID.new
  end

  def deliver_via_nuntium?
    ENV["DELIVER_VIA_NUNTIUM"].nil? || ENV["DELIVER_VIA_NUNTIUM"] != "0"
  end

  def nuntium
    @nuntium ||= Nuntium.new ENV['NUNTIUM_URL'], ENV['NUNTIUM_ACCOUNT'], ENV['NUNTIUM_APPLICATION'], ENV['NUNTIUM_PASSWORD']
  end
end
