class PhoneCall < ActiveRecord::Base
  include Communicable
  include Communicable::FromUser
  include Communicable::Chatable
  include TwilioHelpers
  include ChatStarter

  # the maximum length of a US phone number
  # without the country code
  # note: this is only used to determine whether Twilio added an extra 1 or not
  MAX_LOCAL_NUMBER_LENGTH = 10

  module Digits
    MENU = 8
  end

  module CallStatuses
    COMPLETED = "completed"
  end

  module PromptStates
    extend ActiveSupport::Concern

    USER_INPUTS = {
      :gender => {:manditory => false},
      :looking_for => {:manditory => false},
      :age => {:numDigits => 2}
    }

    # turn voice prompts on or off
    VOICE_PROMPTS = false

    private

    def with_prompt_states(&block)
      USER_INPUTS.dup.each do |attribute, options|
        contexts = [:_in_menu]
        contexts << nil if options.delete(:manditory)
        contexts.each do |context|
          yield(attribute, "asking_for_#{attribute}#{context}".to_sym, options)
        end
      end
    end
  end

  attr_accessor :redirect_url, :digits, :to, :dial_status, :call_status, :api_version
  alias_attribute :call_sid, :sid

  attr_accessible :to, :api_version

  validates :sid, :presence => true, :uniqueness => true

  state_machine :initial => :answered do
    extend PromptStates

    state :answered do
      def to_twiml
        nil.to_s
      end
    end

    state :welcoming_user do
      def to_twiml
        play(:welcome)
      end
    end

    # Menu prompts
    with_prompt_states do |attribute, prompt_state, options|
      before_transition prompt_state => any, :do => :set_profile_from_digits

      state(prompt_state) do
        define_method :to_twiml do
          ask_for_input("ask_for_#{attribute}", options)
        end
      end
    end

    state :offering_menu do
      def to_twiml
        ask_for_input(:offer_menu)
      end
    end

    state :finding_new_friend do
      def to_twiml
        redirect
      end
    end

    state :telling_user_to_try_again_later do
      def to_twiml
        play(:tell_user_to_try_again_later)
      end
    end

    before_transition any => :finding_new_friend, :do => :create_chat_session
    before_transition any => :connecting_user_with_friend, :do => :set_or_update_current_chat
    before_transition any => :completed, :do => :deactivate_chat_for_user

    state :connecting_user_with_friend do
      def to_twiml
        dial(chat.partner(user))
      end
    end

    state :telling_user_their_chat_has_ended do
      def to_twiml
        play(:tell_user_their_chat_has_ended)
      end
    end

    state :completed do
      def to_twiml
        hangup
      end
    end

    event :process! do
      # complete the call if it has finished
      transition(any => :completed, :if => :complete?)

      if PromptStates::VOICE_PROMPTS
        # welcome the user
        transition(:answered => :welcoming_user)

        # offer him the menu
        transition(:welcoming_user => :offering_menu)

        # offer him the menu for more options
        transition(:offering_menu => :asking_for_age_in_menu, :if => :wants_menu?)
        transition(:asking_for_age_in_menu => :asking_for_gender_in_menu)
        transition(:asking_for_gender_in_menu => :asking_for_looking_for_in_menu)
        transition(:asking_for_looking_for_in_menu => :offering_menu)
      end

      # connect him with his existing friend
      transition(
        [:answered, :offering_menu] => :connecting_user_with_friend,
        :if => :user_chatting?
      )

      # find him a new friend
      transition([:answered, :offering_menu] => :finding_new_friend)

      # connect him with his new friend
      transition(:finding_new_friend => :connecting_user_with_friend, :if => :friend_available?)

      if PromptStates::VOICE_PROMPTS
        # tell him his chat has ended
        transition(
          :connecting_user_with_friend => :telling_user_their_chat_has_ended,
          :if => :connected?
        )

        # offer him the menu
        transition(:telling_user_their_chat_has_ended => :offering_menu)
      end

      # find him a new friend
      transition(:connecting_user_with_friend => :finding_new_friend)

      if PromptStates::VOICE_PROMPTS
        # tell him to try again later (no friend available)
        transition(:finding_new_friend => :telling_user_to_try_again_later)
      end

      # complete call
      transition([:finding_new_friend, :telling_user_to_try_again_later] => :completed)
    end
  end

  def self.find_or_create_and_process_by(params, redirect_url)
    params.underscorify_keys!

    phone_call = self.find_or_create_by_sid(params[:call_sid], params.slice(:from, :to))

    if phone_call.valid?
      phone_call.login_user!
      phone_call.redirect_url = redirect_url
      phone_call.digits = params[:digits]
      phone_call.call_status = params[:call_status]
      phone_call.dial_status = params[:dial_call_status]
      phone_call.api_version = params[:api_version]
      phone_call.process!
      phone_call
    end
  end

  def digits
    @digits.to_i
  end

  def to=(value)
    self.from = value if value.present?
  end

  def from=(value)
    # this method is overriden because Twilio adds
    # random 1's to the start of phone numbers
    if value.present?
      if !twilio_number?(value) && value.length >= User::MINIMUM_MOBILE_NUMBER_LENGTH
        # remove non digits
        value.gsub!(/\D/, "")

        if value.first == "1"
          # remove all leading ones
          non_us_number = value.gsub(/\A1+/, "")
          value = non_us_number if non_us_number.length > MAX_LOCAL_NUMBER_LENGTH
        end
        super value
      end
    else
      super value
    end
  end

  def login_user!
    user.login!
  end

  private

  def user_chatting?
    chat.present? || (user.currently_chatting? && user.active_chat.partner(user).available?(user.active_chat))
  end

  alias friend_available? user_chatting?

  def wants_menu?
    digits == Digits::MENU
  end

  def connected?
    dial_status == CallStatuses::COMPLETED
  end

  def complete?
    call_status == CallStatuses::COMPLETED
  end

  def create_chat_session(transition)
    build_chat(:user => user).activate!(:starter => self)
  end

  def set_profile_from_digits(transition)
    return if complete?
    user.send(transition.from.gsub("asking_for_", "").gsub("_in_menu", "") << "=", transition.object.digits)
    user.reload unless user.save
  end

  def set_or_update_current_chat
    self.chat ||= user.active_chat
  end

  def deactivate_chat_for_user
    chat.deactivate!(:active_user => user) if chat.present?
  end

  def play(file, options = {})
    generate_twiml(options) { |twiml| twiml.Play play_url(file) }
  end

  def hangup
    generate_twiml(:redirect => false) { |twiml| twiml.Hangup }
  end

  def dial(user_to_dial)
    generate_twiml(:redirect => false) do |twiml|
      twiml.Dial(
        user_to_dial.dial_string(api_version),
        :callerId => user_to_dial.caller_id(api_version),
        :action => redirect_url
      )
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
