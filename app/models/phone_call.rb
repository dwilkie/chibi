class PhoneCall < ActiveRecord::Base
  include Chibi::Communicable::FromUser
  include Chibi::Communicable::Chatable
  include Chibi::ChatStarter
  include Chibi::ChargeRequester
  include Chibi::Analyzable
  include SaveWithRetry

  include AASM

  DEFAULT_MAX_SIMULTANIOUS_DIALS = 5
  ANONYMOUS_FROM = "anonymous"

  module CallStatuses
    COMPLETED = "completed"
  end

  attr_accessor :request_url, :to, :call_params
  alias_attribute :call_sid, :sid

  validates :user, :associated => true, :presence => true
  validates :sid, :presence => true

  aasm :column => :state, :whiny_transitions => false do
    state :answered, :initial => true
    state :transitioning_from_answered
    state :telling_user_they_dont_have_enough_credit
    state :transitioning_from_telling_user_they_dont_have_enough_credit
    state :connecting_user_with_friend
    state :transitioning_from_connecting_user_with_friend
    state :finding_friends
    state :transitioning_from_finding_friends
    state :dialing_friends
    state :transitioning_from_dialing_friends
    state :awaiting_completion
    state :completed

    event :flag_as_processing, :after_commit => :queue_for_processing! do
      transitions(:from => :answered, :to => :transitioning_from_answered)
      transitions(
        :from => :telling_user_they_dont_have_enough_credit,
        :to => :transitioning_from_telling_user_they_dont_have_enough_credit
      )
      transitions(
        :from => :connecting_user_with_friend,
        :to => :transitioning_from_connecting_user_with_friend
      )
      transitions(
        :from => :finding_friends,
        :to => :transitioning_from_finding_friends
      )
      transitions(
        :from => :dialing_friends,
        :to => :transitioning_from_dialing_friends
      )
    end

    event :complete do
      transitions(:to => :completed)
    end

    event :process, :after_commit => :fetch_twilio_cdr do
      # if the charge failed
      # tell him that he doesn't have enough credit
      transitions(
        :from => :transitioning_from_answered,
        :to => :telling_user_they_dont_have_enough_credit,
        :if => :charge_failed?
      )

      # then hang up
      transitions(
        :from => :transitioning_from_telling_user_they_dont_have_enough_credit,
        :to => :awaiting_completion,
      )

      # if can dial to current chat parter
      # connect him with his existing friend
      transitions(
        :from => :transitioning_from_answered,
        :to => :connecting_user_with_friend,
        :if => :can_dial_to_partner?,
        :after => :set_or_update_current_chat
      )

      # if the friend answered
      # hang up
      transitions(
        :from => :transitioning_from_connecting_user_with_friend,
        :to => :awaiting_completion,
        :if => :connected?
      )

      # otherwise find him new friends
      transitions(
        :from => :transitioning_from_connecting_user_with_friend,
        :to => :finding_friends,
        :after => :find_friends
      )

      # find him new friends
      transitions(
        :from => :transitioning_from_answered,
        :to => :finding_friends,
        :after => :find_friends
      )

      # if available call his new friends
      transitions(
        :from => :transitioning_from_finding_friends,
        :to => :dialing_friends,
        :if => :friends_available?
      )

      # otherwise hangup
      transitions(
        :from => :transitioning_from_finding_friends,
        :to => :awaiting_completion
      )

      # if he's connected with a friend hang up
      transitions(
        :from => :transitioning_from_dialing_friends,
        :to => :awaiting_completion,
        :if => :connected?
      )

      # otherwise find him new friends
      transitions(
        :from => :transitioning_from_dialing_friends,
        :to => :finding_friends,
        :after => :find_friends
      )
    end
  end

  def to_twiml
    send("twiml_for_#{state}")
  end

  def self.answer!(params, request_url)
    phone_call = new
    phone_call.set_call_params(params, request_url, true)
    return phone_call if phone_call.anonymous?
    save_with_retry! { phone_call.save! }
    phone_call.pre_process!
    phone_call
  end

  def self.complete!(params)
    call_params = params.underscorify_keys
    return if !(phone_call = where(:sid => call_params["call_sid"]).first)
    phone_call.duration = call_params["call_duration"]
    phone_call.complete!
  end

  def set_call_params(call_params, request_url = nil, initialize = false)
    call_params = call_params.underscorify_keys

    self.call_params = call_params
    self.request_url = request_url

    if initialize
      self.from = call_params["from"]
      self.to = call_params["to"]
      self.sid = call_params["call_sid"]
    end
  end

  def anonymous?
    (call_params || {})["from"].to_s.downcase == ANONYMOUS_FROM
  end

  def pre_process!
    if user.blacklisted?
      user.logout!
    else
      user.login!
      user.charge!(self)
    end
  end

  def to=(value)
    self.from = value if value.present?
  end

  def fetch_inbound_twilio_cdr!
    do_fetch_twilio_cdr!(sid)
  end

  def fetch_outbound_twilio_cdr!
    do_fetch_twilio_cdr!(dial_call_sid)
  end

  private

  def do_fetch_twilio_cdr!(cdr_sid)
    if call_sid.present? && twilio_cdr = CallDataRecord::Twilio.first_or_initialize(:uuid => cdr_sid)
      if twilio_cdr.new_record?
        twilio_cdr.fetch!
        twilio_cdr.save
      end
    end
  end

  def queue_for_processing!
    PhoneCallProcessorJob.perform_later(id, call_params, request_url)
  end

  def twiml_for_answered
    (anonymous? || user.blacklisted?) ? hangup : redirect_to_self("POST")
  end

  def twiml_for_transitioning_from_answered
    redirect_to_self
  end

  def twiml_for_telling_user_they_dont_have_enough_credit
    play(:not_enough_credit)
  end

  def twiml_for_transitioning_from_telling_user_they_dont_have_enough_credit
    redirect_to_self
  end

  def twiml_for_awaiting_completion
    hangup
  end

  def twiml_for_completed
    hangup
  end

  def twiml_for_connecting_user_with_friend
    dial(chat.partner(user))
  end

  def twiml_for_transitioning_from_connecting_user_with_friend
    redirect_to_self
  end

  def twiml_for_finding_friends
    redirect_to_self("POST")
  end

  def twiml_for_transitioning_from_finding_friends
    redirect_to_self
  end

  def twiml_for_dialing_friends
    dial(*new_friends)
  end

  def twiml_for_transitioning_from_dialing_friends
    redirect_to_self
  end

  def charge_failed?
    charge_request && charge_request.failed?
  end

  def from_adhearsion_twilio?
    adhearsion_twilio_requested?(call_params["api_version"])
  end

  def from_twilio?
    !from_adhearsion_twilio?
  end

  def fetch_twilio_cdr
    from_twilio? ? TwilioCdrFetcherJob.perform_later(id) : nil
  end

  def can_dial_to_partner?
    user.currently_chatting? && (current_chat.active? || current_partner.available?)
  end

  def current_partner
    @current_partner ||= current_chat.partner(user)
  end

  def set_or_update_current_chat
    self.chat ||= user.active_chat
  end

  def current_chat
    @current_chat ||= user.active_chat
  end

  def find_friends
    set_or_update_current_chat
    ask_partner_to_contact_me if user.currently_chatting? && !can_dial_to_partner?
    Chat.activate_multiple!(user, :starter => self, :limit => max_simultaneous_dials)
  end

  def new_friends
    @new_friends ||= triggered_chats.order("created_at DESC").includes(:friend).limit(max_simultaneous_dials).map(&:friend)
  end

  def friends_available?
    triggered_chats.any?
  end

  def ask_partner_to_contact_me
    to = current_partner
    current_chat.replies.build(:user => to).contact_me(user)
  end

  def connected?
    call_params["dial_call_status"] == CallStatuses::COMPLETED
  end

  def complete?
    call_status == CallStatuses::COMPLETED
  end

  def play(file, options = {})
    generate_twiml(options) { |twiml| twiml.Play play_url(file) }
  end

  def hangup
    generate_twiml(:redirect => false) { |twiml| twiml.Hangup }
  end

  def dial(*users_to_dial)
    generate_twiml(:redirect => false) do |twiml|
      dial_options = {:action => redirect_url, :method => "POST", :ringback => play_url(:ringback_tone)}
      dial_options.merge!(:callerId => twilio_outgoing_number) if from_twilio?
      twiml.Dial(dial_options) do
        users_to_dial.each do |user_to_dial|
          number_options = {}
          api_version = call_params["api_version"]
          number_options.merge!(:callerId => user_to_dial.caller_id(api_version)) if from_adhearsion_twilio?
          twiml.Number(user_to_dial.dial_string(api_version), number_options)
        end
      end
    end
  end

  def generate_twiml(options = {}, &block)
    response = Twilio::TwiML::Response.new do |twiml|
      yield twiml if block_given?
      twiml.Redirect(
        redirect_url,
        :method => (options[:redirect_method] || "POST").to_s.upcase
      ) unless options[:redirect] == false
    end

    response.text
  end

  def redirect_to_self(redirect_method = "GET")
    generate_twiml(:redirect_method => redirect_method)
  end

  def redirect_url
    return @redirect_url if @redirect_url
    uri = URI.parse(request_url)
    uri.path = Rails.application.routes.url_helpers.phone_call_path(self)
    uri.query = nil
    @redirect_url = uri.to_s
  end

  def play_url(filename)
    "https://s3.amazonaws.com/chibimp3/#{play_path_prefix}/#{filename}.mp3"
  end

  def play_path_prefix
    I18n.t(:play_path_prefix, :locale => user.locale)
  end

  def max_simultaneous_dials
    (Rails.application.secrets[:phone_call_max_simultaneous_dials] || DEFAULT_MAX_SIMULTANIOUS_DIALS).to_i
  end
end
