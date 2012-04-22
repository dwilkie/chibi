class PhoneCall < ActiveRecord::Base
  include Communicable
  include Communicable::Chatable
  include TwilioHelpers

  module Digits
    MENU = 8
    WANTS_EXISTING_FRIEND = 1
    WANTS_NEW_FRIEND = 2
  end

  module CallStatuses
    COMPLETED = "completed"
  end

  module PromptStates

    USER_INPUTS = {
      :gender => {:manditory => true},
      :looking_for => {:manditory => true},
      :age => {:numDigits => 2}
    }

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

  attr_accessor :redirect_url, :digits, :to, :dial_status, :call_status
  alias_attribute :call_sid, :sid

  attr_accessible :to

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

    before_transition(
      :asking_if_user_wants_to_find_a_new_friend_or_call_existing_one => any,
      :do => :check_user_preference_for_finding_a_new_friend_or_calling_existing_one
    )

    state :asking_if_user_wants_to_find_a_new_friend_or_call_existing_one do
      def to_twiml
        ask_for_input(:ask_if_they_want_to_find_a_new_friend_or_call_existing_chat_partner)
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

    state :telling_user_their_friend_is_unavailable do
      def to_twiml
        play(:tell_user_their_friend_is_unavailable)
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

      # welcome the user
      transition(:answered => :welcoming_user)

      # ask him for any required attributes
      transition(:welcoming_user => :asking_for_gender, :if => :ask_for_gender?)
      transition([:welcoming_user, :asking_for_gender] => :asking_for_looking_for, :if => :ask_for_looking_for?)
      transition([:welcoming_user, :asking_for_gender, :asking_for_looking_for] => :offering_menu)

      # offer him the menu for more options
      transition(:offering_menu => :asking_for_age_in_menu, :if => :wants_menu?)
      transition(:asking_for_age_in_menu => :asking_for_gender_in_menu)
      transition(:asking_for_gender_in_menu => :asking_for_looking_for_in_menu)
      transition(:asking_for_looking_for_in_menu => :offering_menu)

      # ask him if he wants to chat with his existing friend
      transition(
        :offering_menu => :asking_if_user_wants_to_find_a_new_friend_or_call_existing_one,
        :if => :user_chatting?
      )

      # find him a new friend
      transition(:offering_menu => :finding_new_friend)

      # connect him with his new friend
      transition(:finding_new_friend => :connecting_user_with_friend, :if => :friend_available?)

      # tell him to try again later (no friend available)
      transition(:finding_new_friend => :telling_user_to_try_again_later)

      # complete call
      transition(:telling_user_to_try_again_later => :completed)

      # find a new friend for him
      transition(
        :asking_if_user_wants_to_find_a_new_friend_or_call_existing_one => :finding_new_friend,
        :if => :wants_new_friend?
      )

      # connect him with his existing friend
      transition(
        :asking_if_user_wants_to_find_a_new_friend_or_call_existing_one => :connecting_user_with_friend,
        :if => :wants_existing_friend?
      )

      # tell him his friend is unavailable
      transition(
        :asking_if_user_wants_to_find_a_new_friend_or_call_existing_one => :telling_user_their_friend_is_unavailable
      )

      # find him a new friend
      transition(:telling_user_their_friend_is_unavailable => :finding_new_friend)

      # tell him his chat has ended
      transition(:connecting_user_with_friend => :telling_user_their_chat_has_ended, :if => :connected?)

      # find him a new friend
      transition(:connecting_user_with_friend => :finding_new_friend)

      # offer him the menu
      transition(:telling_user_their_chat_has_ended => :offering_menu)
    end
  end

  def self.find_or_create_and_process_by(params, redirect_url)
    params.underscorify_keys!

    phone_call = self.find_or_initialize_by_sid(params[:call_sid], params.slice(:from, :to))

    if phone_call.valid?
      phone_call.login_user!
      phone_call.redirect_url = redirect_url
      phone_call.digits = params[:digits]
      phone_call.call_status = params[:call_status]
      phone_call.dial_status = params[:dial_call_status]
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

  def login_user!
    user.login!
  end

  private

  def ask_for_gender?
    !user.gender?
  end

  def ask_for_looking_for?
    !user.looking_for?
  end

  def user_chatting?
    chat.present? || user.currently_chatting?
  end

  alias friend_available? user_chatting?

  def wants_menu?
    digits == Digits::MENU
  end

  def wants_new_friend?
    digits == Digits::WANTS_NEW_FRIEND
  end

  def wants_existing_friend?
    digits == Digits::WANTS_EXISTING_FRIEND
  end

  def connected?
    dial_status == CallStatuses::COMPLETED
  end

  def complete?
    call_status == CallStatuses::COMPLETED
  end

  def create_chat_session(transition)
    build_chat(:user => user).activate!
  end

  def set_profile_from_digits(transition)
    return if complete?
    user.send(transition.from.gsub("asking_for_", "").gsub("_in_menu", "") << "=", transition.object.digits)
    user.save
  end

  def set_or_update_current_chat
    self.chat ||= user.active_chat
  end

  def deactivate_chat_for_user
    chat.deactivate!(:active_user => user) if chat.present?
  end

  def check_user_preference_for_finding_a_new_friend_or_calling_existing_one
    return if complete?
    wants_existing_friend? || wants_new_friend? || !user_chatting?
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
        user_to_dial.mobile_number,
        :callerId => user_to_dial.short_code || twilio_outgoing_number,
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
      url = URI.parse(redirect_url)
      url.query = "redirect=true"
      redirect_url = url.to_s
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
