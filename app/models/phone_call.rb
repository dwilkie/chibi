class PhoneCall < ActiveRecord::Base
  include Communicable

  module Digits
    MALE = 1
    FEMALE = 2
    MENU = 8
  end

  attr_accessor :redirect_url, :digits
  alias_attribute :call_sid, :sid

  validates :sid, :presence => true, :uniqueness => true

  state_machine :initial => :answered do

    prompt_transitions = []

    [:gender, :looking_for].each do |attribute|
      [nil, :_in_menu].each do |context|
        prompt_transitions << "asking_for_#{attribute}#{context}".to_sym
      end
    end

    before_transition prompt_transitions => any, :do => :set_profile_from_digits

    event :process! do
      transition :answered => :welcoming_user
      transition :welcoming_user => :asking_for_gender, :if => :ask_for_gender?
      transition [:welcoming_user, :asking_for_gender] => :asking_for_looking_for, :if => :ask_for_looking_for?
      transition [:welcoming_user, :asking_for_gender, :asking_for_looking_for] => :offering_menu
      transition :offering_menu => :asking_for_gender_in_menu, :if => :wants_menu?
      transition :asking_for_gender_in_menu => :asking_for_looking_for_in_menu
      transition :asking_for_looking_for_in_menu => :offering_menu
      transition :offering_menu => :connecting_user_with_friend
    end

    state :welcoming_user do
      def to_twiml
        generate_twiml { |twiml| twiml.Play play_url(:welcome) }
      end
    end

    state :asking_for_gender do
      def to_twiml
        ask_for_input(:gender)
      end
    end

    state :asking_for_looking_for do
      def to_twiml
        ask_for_input(:looking_for)
      end
    end
  end

  def digits
    @digits.to_i
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
    profile_attribute_setter_method = transition.from.gsub("asking_for_", "").gsub("_in_menu", "") << "="
    digits = transition.object.digits

    if digits == Digits::MALE
      profile_attribute_value = "m"
    elsif digits == Digits::FEMALE
      profile_attribute_value = "f"
    end

    if profile_attribute_value
      user.send(profile_attribute_setter_method, profile_attribute_value)
      user.save
    end

    profile_attribute_value.present?
  end

  def ask_for_input(prompt)
    generate_twiml do |twiml|
      twiml.Gather(:numDigits => 1) { |gather| gather.Play play_url("ask_for_#{prompt}") }
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
