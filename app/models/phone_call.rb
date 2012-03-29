class PhoneCall < ActiveRecord::Base
  include Communicable
  include Communicable::Chatable
  include TwilioHelpers

  module Digits
    MENU = 8
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

    state :connecting_user_with_new_friend do
      def to_twiml
        dial(user.match)
      end
    end

    before_transition any => :connecting_user_with_existing_friend, :do => :set_or_update_current_chat

    state :connecting_user_with_existing_friend do
      def to_twiml
        dial(chat.partner(user))
      end
    end

    state :telling_user_their_friend_is_unavailable do
      def to_twiml
        play(:tell_user_their_friend_is_unavailable)
      end
    end

    state :hanging_up do
      def to_twiml
        hangup
      end
    end

    state :completed do
      def to_twiml
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
      transition(:finding_new_friend => :connecting_user_with_new_friend, :if => :friend_available?)

      # tell him to try again later (no friend available)
      transition(:finding_new_friend => :telling_user_to_try_again_later)

      # hang up
      transition(:telling_user_to_try_again_later => :hanging_up)

      transition(
        :asking_if_user_wants_to_find_a_new_friend_or_call_existing_one => :connecting_user_with_new_friend,
        :if => :wants_new_friend?
      )

      transition(
        :asking_if_user_wants_to_find_a_new_friend_or_call_existing_one => :connecting_user_with_existing_friend,
        :if => :user_chatting?
      )

      transition(
        :asking_if_user_wants_to_find_a_new_friend_or_call_existing_one => :telling_user_their_friend_is_unavailable
      )

      transition(:telling_user_their_friend_is_unavailable => :connecting_user_with_new_friend)

      transition(:connecting_user_with_new_friend => :hanging_up, :if => :connected?)
    end
  end

  def digits
    @digits.to_i
  end

  def to=(value)
    self.from = value if value.present?
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
