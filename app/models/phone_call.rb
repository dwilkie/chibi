class PhoneCall < ActiveRecord::Base
  include Communicable
  include Communicable::Chatable

  module Digits
    MENU = 8
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

  attr_accessor :redirect_url, :digits, :to
  alias_attribute :call_sid, :sid

  attr_accessible :to

  validates :sid, :presence => true, :uniqueness => true

  state_machine :initial => :answered do
    extend PromptStates

    state :welcoming_user do
      def to_twiml
        generate_twiml { |twiml| twiml.Play play_url(:welcome) }
      end
    end

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

    state :connecting_user_with_friend do
      def to_twiml
        generate_twiml { |twiml| twiml.Dial(user.match.mobile_number, :callerId => user.short_code) }
      end
    end

    event :process! do
      transition :answered => :welcoming_user
      transition :welcoming_user => :asking_for_gender, :if => :ask_for_gender?
      transition [:welcoming_user, :asking_for_gender] => :asking_for_looking_for, :if => :ask_for_looking_for?
      transition [:welcoming_user, :asking_for_gender, :asking_for_looking_for] => :offering_menu

      # Menu
      transition :offering_menu => :asking_for_age_in_menu, :if => :wants_menu?
      transition :asking_for_age_in_menu => :asking_for_gender_in_menu
      transition :asking_for_gender_in_menu => :asking_for_looking_for_in_menu
      transition :asking_for_looking_for_in_menu => :offering_menu

      transition :offering_menu => :connecting_user_with_friend
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

  def wants_menu?
    digits == Digits::MENU
  end

  def set_profile_from_digits(transition)
    user.send(transition.from.gsub("asking_for_", "").gsub("_in_menu", "") << "=", transition.object.digits)
    user.save
  end

  def ask_for_input(prompt, options = {})
    options[:numDigits] ||= 1
    generate_twiml do |twiml|
      twiml.Gather(options) { |gather| gather.Play play_url(prompt) }
    end
  end

  def generate_twiml(options = {}, &block)
    response = Twilio::TwiML::Response.new do |twiml|
      yield twiml
      options[:hangup] ? twiml.Hangup : twiml.Redirect(redirect_url)
    end

    response.text
  end

  def play_url(filename)
    "https://s3.amazonaws.com/chibimp3/#{play_path_prefix}/#{filename}.mp3"
  end

  def play_path_prefix
    I18n.t(:play_path_prefix, :locale => user.locale)
  end

end
