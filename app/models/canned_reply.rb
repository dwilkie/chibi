class CannedReply
  def initialize(locale, options = {})
    @locale = locale
    @sender = options[:sender] || options[:friend]
    @recipient = options[:recipient]
    @sender_name = screen_name(@sender)
    @recipient_name = screen_name(@recipient)
  end

  def greeting
    random_sample(:greetings, interpolations)
  end

  def call_me(on)
    random_sample(:call_me, interpolations.merge(:on => call_me_on(on), :call_sms => call_or_sms))
  end

  private

  def interpolations
    {
      :recipient_name => @recipient_name,
      :recipient_greeting => recipient_greeting,
      :recipient_questions => recipient_questions,
      :sender_introduction => sender_introduction,
      :sender_name => @sender_name,
      :sender_city => city(@sender)
    }
  end

  def screen_name(user)
    " #{user.screen_id}" if user.try(:name)
  end

  def city(user)
    user.city || "pp"
  end

  def sender_introduction
    sender_intro = ""
    sender_intro << name_announcement if @sender_name
    sender_intro << gender_announcement if @sender.try(:female?)
    sender_intro << "." unless sender_intro.empty?
    sender_intro
  end

  def call_or_sms
    methods = [random_sample(:sms)]
    methods << random_sample(:call) if @recipient.can_call_short_code?
    methods.join(" #{random_sample(:or)} ")
  end

  def call_me_on(on)
    "#{random_sample(:call_me_prepositions)} #{on}"
  end

  def recipient_greeting
    "#{random_sample(:greeting_starters)}#{screen_name(@recipient)}#{random_sample(:greeting_punctuation_marks)}"
  end

  def recipient_questions
    questions = []
    questions << random_sample(:name_questions) unless @recipient_name.present?
    questions << random_sample(:you) + " " + random_sample(:gender_questions) unless @recipient.try(:gender).present?
    questions << random_sample(:location_questions) unless @recipient.try(:city).present?
    questions << random_sample(:age_questions) unless @recipient.try(:age).present?
    " #{questions.shuffle.join(' ')}"
  end

  def gender_announcement
    " #{random_sample(:i_ams)} #{random_sample('genders.female')} #{random_sample('softeners.female')}"
  end

  def name_announcement
    " #{random_sample(:name_announcements, :i_ams)}#{@sender_name}"
  end

  def random_sample(*keys)
    interpolations = keys.extract_options!
    pool = []
    keys.each do |key|
      pool |= translation_samples(
        key, interpolations.merge(:locale => @locale)
      ) | translation_samples(key, interpolations)
    end
    sample = pool.sample
    sample.capitalize! if rand < (1.0/2)
    sample
  end

  def translation_samples(key, options = {})
    samples = I18n.t(key, options.merge(:default => ""))
    samples = samples.split if samples.is_a?(String)
    samples.map { |sample| I18n.interpolate(sample, options) }
  end
end
