class PhoneCall < ActiveRecord::Base
  include Chibi::Communicable
  include Chibi::Communicable::FromUser
  include Chibi::Communicable::Chatable
  include Chibi::ChatStarter
  include Chibi::ChargeRequester
  include Chibi::Analyzable

  include AASM

  # The maximum number of concurrent outbound dials to trigger
  MAX_SIMULTANEOUS_OUTBOUND_DIALS = 5

  module Digits
    MENU = 8
  end

  module CallStatuses
    COMPLETED = "completed"
  end

  attr_accessor :redirect_url, :digits, :to, :dial_status, :call_status, :api_version
  alias_attribute :call_sid, :sid

  validates :sid, :presence => true, :uniqueness => true
  validates :dial_call_sid, :uniqueness => true, :allow_nil => true

  delegate :charge!, :login!, :to => :user, :prefix => true

  aasm :column => :state, :whiny_transitions => false do
    state :answered, :initial => true
    state :telling_user_they_dont_have_enough_credit
    state :finding_new_friends
    state :connecting_user_with_friend
    state :dialing_friends
    state :completed

    event :process, :after_commit => :fetch_twilio_cdr do
      # complete the call if it has finished
      transitions(
        :from => [
          :answered,
          :telling_user_they_dont_have_enough_credit,
          :finding_new_friends,
          :connecting_user_with_friend,
          :dialing_friends,
        ],
        :to => :completed,
        :if => :complete?
      )

      # tell him that he doesn't have enough credit if the charge failed
      transitions(
        :from => :answered,
        :to => :telling_user_they_dont_have_enough_credit,
        :if => :charge_failed?
      )

      transitions(
        :from => :telling_user_they_dont_have_enough_credit,
        :to => :completed
      )

      # connect him with his existing friend
      transitions(
        :from => :answered,
        :to => :connecting_user_with_friend,
        :if => :can_dial_to_partner?,
        :after => :set_or_update_current_chat
      )

      # find him new friends
      transitions(
        :from => :answered,
        :to => :finding_new_friends,
        :after => :find_friends
      )

      # connect him with his new friend
      transitions(
        :from => :finding_new_friends,
        :to => :dialing_friends,
        :if => :friends_available?
      )

      # hangup if the call has ended
      transitions(
        :from => [:connecting_user_with_friend, :dialing_friends],
        :to => :completed,
        :if => :connected?
      )

      # find him a new friend
      transitions(
        :from => [:dialing_friends, :connecting_user_with_friend],
        :to => :finding_new_friends,
        :after => :find_friends
      )

      # complete call
      transitions(
        :from => :finding_new_friends,
        :to => :completed,
      )
    end
  end

  def to_twiml
    send("twiml_for_#{state}")
  end

  def self.find_or_create_and_process_by(params, redirect_url)
    params.underscorify_keys!

    phone_call = find_or_initialize_by(:sid => params[:call_sid]) do |pc|
      pc.from = params[:from]
      pc.to = params[:to]
    end

    if phone_call.valid?
      phone_call.user_login!
      phone_call.redirect_url = redirect_url
      phone_call.digits = params[:digits]
      phone_call.call_status = params[:call_status]
      phone_call.dial_status = params[:dial_call_status]
      phone_call.dial_call_sid ||= params[:dial_call_sid]
      phone_call.api_version = params[:api_version]
      phone_call.save!
      charge_request = phone_call.charge_request
      phone_call.process! if (charge_request.nil? && phone_call.user_charge!(phone_call)) || (charge_request && charge_request.slow?)
      phone_call
    end
  end

  def digits
    @digits.to_i
  end

  def to=(value)
    self.from = value if value.present?
  end

  def fetch_inbound_twilio_cdr!
    Chibi::Twilio::InboundCdr.create(:uuid => sid)
  end

  def fetch_outbound_twilio_cdr!
    Chibi::Twilio::OutboundCdr.create(:uuid => dial_call_sid) if dial_call_sid.present?
  end

  private

  def twiml_for_answered
    redirect
  end

  def twiml_for_telling_user_they_dont_have_enough_credit
    play(:not_enough_credit)
  end

  def twiml_for_finding_new_friends
    redirect
  end

  def twiml_for_connecting_user_with_friend
    dial(chat.partner(user))
  end

  def twiml_for_dialing_friends
    dial(*new_friends)
  end

  def twiml_for_completed
    hangup
  end

  def charge_failed?
    charge_request && charge_request.failed?
  end

  def from_adhearsion_twilio?
    adhearsion_twilio_requested?(api_version)
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

  def current_chat
    @current_chat ||= user.active_chat
  end

  def find_friends
    set_or_update_current_chat
    ask_partner_to_contact_me if user.currently_chatting? && !can_dial_to_partner?
    Chat.activate_multiple!(user, :starter => self, :count => MAX_SIMULTANEOUS_OUTBOUND_DIALS)
  end

  def new_friends
    @new_friends ||= triggered_chats.order("created_at DESC").includes(:friend).limit(MAX_SIMULTANEOUS_OUTBOUND_DIALS).map(&:friend)
  end

  def friends_available?
    triggered_chats.any?
  end

  def ask_partner_to_contact_me
    to = current_partner
    current_chat.replies.build(:user => to).contact_me(user)
  end

  def wants_menu?
    digits == Digits::MENU
  end

  def connected?
    dial_status == CallStatuses::COMPLETED
  end

  def complete?
    call_status == CallStatuses::COMPLETED
  end

  def set_profile_from_digits(transition)
    return if complete?
    user.send(transition.from.gsub("asking_for_", "").gsub("_in_menu", "") << "=", transition.object.digits)
    user.reload unless user.save
  end

  def set_or_update_current_chat
    self.chat ||= user.active_chat
  end

  def play(file, options = {})
    generate_twiml(options) { |twiml| twiml.Play play_url(file) }
  end

  def hangup
    generate_twiml(:redirect => false) { |twiml| twiml.Hangup }
  end

  def dial(*users_to_dial)
    generate_twiml(:redirect => false) do |twiml|
      dial_options = { :action => redirect_url }
      dial_options.merge!(:callerId => twilio_outgoing_number) if from_twilio?
      twiml.Dial(dial_options) do
        users_to_dial.each do |user_to_dial|
          number_options = {}
          number_options.merge!(:callerId => user_to_dial.caller_id(api_version)) if from_adhearsion_twilio?
          twiml.Number(user_to_dial.dial_string(api_version), number_options)
        end
      end
    end
  end

  def ask_for_input(prompt, options = {})
    options[:numDigits] ||= 1
    generate_twiml do |twiml|
      twiml.Gather(options) { |gather| gather.Play play_url(prompt) }
    end
  end

  def generate_twiml(options = {}, &block)
    response = Twilio::TwiML::Response.new do |twiml|
      yield twiml if block_given?
      twiml.Redirect(redirect_url) unless options[:redirect] == false
    end

    response.text
  end

  alias redirect generate_twiml

  def play_url(filename)
    "https://s3.amazonaws.com/chibimp3/#{play_path_prefix}/#{filename}.mp3"
  end

  def play_path_prefix
    I18n.t(:play_path_prefix, :locale => user.locale)
  end
end
