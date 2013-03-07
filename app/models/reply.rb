class Reply < ActiveRecord::Base
  include Communicable
  include Communicable::Chatable
  include Analyzable

  has_many :delivery_receipts

  DELIVERED = "delivered"
  FAILED = "failed"
  CONFIRMED = "confirmed"

  validates :to, :body, :presence => true
  validates :token, :uniqueness => true, :allow_nil => true

  alias_attribute :destination, :to

  before_validation :set_destination

  state_machine :initial => :pending_delivery, :action => :save_with_state_check do
    state :pending_delivery,
          :queued_for_smsc_delivery,
          :delivered_by_smsc,
          :rejected,
          :failed,
          :confirmed

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
    scoped.where("delivered_at IS NOT NULL")
  end

  def self.last_delivered
    scoped.delivered.order(:delivered_at).last
  end

  def self.undelivered
    scoped.where(:delivered_at => nil).order(:created_at)
  end

  def self.query_queued!
    queued_for_smsc_delivery.where("delivered_at < ?", 10.minutes.ago).where("body IS NOT NULL").find_each do |reply|
      Resque.enqueue(NuntiumAoQueryer, reply.id)
    end
  end

  def self.redeliver_blank!
    queued_for_smsc_delivery.where(:body => nil).find_each do |reply|
      Resque.enqueue(BlankReplyRedeliverer, reply.id)
    end
  end

  def query_nuntium_ao!
    if token.present? && body.present?
      ao = nuntium.get_ao(token).first
      undeliver! if ao["body"].blank?
      update_delivery_state(:state => ao["state"])
    end
  end

  def redeliver_blank!
    if body.blank? && chat.present?
      replies = chat.replies.order(:id).all
      if message_to_forward = chat.messages.order(:id).all[replies.index(self) - 1]
        set_forward_message(message_to_forward.user, message_to_forward.body)
        undeliver!
        chat.reactivate!
      end
    end
  end

  def body
    read_attribute(:body).to_s
  end

  def locale
    raw_locale = read_attribute(:locale)
    raw_locale.to_s.downcase.to_sym if raw_locale
  end

  def delivered?
    delivered_at.present?
  end

  def logout!(partner = nil)
    explain_how_to_start_a_new_chat!(:logout, :partner => partner)
  end

  def end_chat!(partner, options = {})
    explain_how_to_start_a_new_chat!(:no_answer, options)
  end

  def instructions_for_new_chat!
    explain_how_to_start_a_new_chat!(:no_answer, :skip_update_profile_instructions => true)
  end

  def explain_could_not_find_a_friend!
    explain_how_to_start_a_new_chat!(:could_not_find_a_friend)
  end

  def explain_friend_is_unavailable!(partner)
    explain_how_to_start_a_new_chat!(:friend_unavailable, :partner => partner)
  end

  def forward_message(from, message)
    set_forward_message(from, message)
    save
  end

  def forward_message!(from, message)
    forward_message(from, message)
    deliver!
  end

  def introduce!(partner, to_initiator, introduction = nil)
    if to_initiator
      translate(
        "replies.new_chat_started",
        :users_name => user.name,
        :friends_screen_name => partner.screen_id
      )
    else
      introduction ||= default_translation("replies.greeting", user.locale, :friend => partner, :recipient => user)
      set_forward_message(partner, introduction)
    end
    deliver!
  end

  def send_reminder!
    translate("replies.greeting", :recipient => user)
    deliver!
  end

  def welcome!
    translate("replies.welcome", :default_locale => user.country_code.to_sym)
    deliver!
  end

  def deliver_alternate_translation!
    if delivered? && alternate_translation? && locale?
      delivery = locale == user.locale ? body : alternate_translation
      perform_delivery!(delivery)
    end
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

  def self.queued_for_smsc_delivery
    scoped.where(:state => "queued_for_smsc_delivery").where("token IS NOT NULL")
  end

  def undeliver!
    self.delivered_at = nil
    save!
  end

  def save_with_state_check
    return save if @force_state_update
    if valid?
      state_attribute = self.class.state_machine.attribute
      self.class.update_all(
        { state_attribute => state },
        { self.class.primary_key => id, state_attribute => state_was }
      ) == 1
    end
  end

  def set_forward_message(from, message)
    message.gsub!(/\A#{from.screen_id}\s*\:?\s*/i, "")
    self.body = "#{from.screen_id}: #{message}"
  end

  def translate(key, interpolations = {})
    user_locale = user.locale
    users_default_locale = user.country_code.to_sym

    # if the user's locale == their default locale
    # the alternate translation locale will be nil
    # I18n will therefore automatically drop back to English
    alternate_translation_locale = users_default_locale unless user_locale == users_default_locale

    self.locale = user_locale
    set_from_translation(key, user_locale, alternate_translation_locale, interpolations)
  end

  def set_from_translation(key, user_locale, alternate_translation_locale, interpolations = {})
    self.body = default_translation(key, user_locale, interpolations)
    self.alternate_translation = I18n.t(key, interpolations.merge(:locale => alternate_translation_locale))
  end

  def default_translation(key, user_locale, interpolations = {})
    I18n.t(key, interpolations.merge(:locale => user_locale))
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

  def explain_how_to_start_a_new_chat!(action, options = {})
    missing_profile_attributes = user.missing_profile_attributes unless options[:skip_update_profile_instructions]
    translate(
      "replies.how_to_start_a_new_chat",
      :action => action,
      :users_name => user.name,
      :friends_screen_name => options[:partner].try(:screen_id),
      :missing_profile_attributes => missing_profile_attributes
    )
    deliver!
  end

  def perform_delivery!(message)
    save! if new_record? # ensure message is saved so we don't get a blank destination
    # use an array so Nuntium sends a POST
    response = nuntium.send_ao([{:to => "sms://#{destination}", :body => message}])
    self.token = response["token"]
    save!
  end

  def nuntium
    @nuntium ||= Nuntium.new ENV['NUNTIUM_URL'], ENV['NUNTIUM_ACCOUNT'], ENV['NUNTIUM_APPLICATION'], ENV['NUNTIUM_PASSWORD']
  end
end
