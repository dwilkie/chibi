# encoding: utf-8

class User < ActiveRecord::Base
  include Chibi::Analyzable
  include Chibi::Twilio::ApiHelpers
  include Chibi::Communicable::HasCommunicableResources

  has_communicable_resources :phone_calls, :messages, :replies

  PROFILE_ATTRIBUTES = [:name, :date_of_birth, :gender, :city, :looking_for]
  MALE = "m"
  FEMALE = "f"
  MINIMUM_MOBILE_NUMBER_LENGTH = 9

  has_one :location, :autosave => true

  # describes initiated chats i.e. chat initiated by user
  has_many :chats
  has_many :friends, :through => :chats

  # decribes accepted friendships i.e. chat initiated by accepted friend
  has_many :participating_chats, :class_name => "Chat", :foreign_key => "friend_id"
  has_many :chat_friends, :through => :participating_chats, :source => :user

  belongs_to :active_chat, :class_name => "Chat"

  validates :mobile_number, :presence => true, :uniqueness => true, :length => {:minimum => MINIMUM_MOBILE_NUMBER_LENGTH}
  validates :location, :screen_name, :presence => true

  validates :gender, :inclusion => {:in => [MALE, FEMALE], :allow_nil => true}
  validates :looking_for, :inclusion => {:in => [MALE, FEMALE], :allow_nil => true}
  validates :age, :inclusion => {:in => 10..99, :allow_nil => true}

  before_validation(:on => :create) do
    self.screen_name = Faker::Name.first_name.downcase unless screen_name.present?
    assign_location if mobile_number.present?
  end

  before_save :cancel_searching_for_friend_if_chatting

  delegate :city, :country_code, :to => :location, :allow_nil => true

  state_machine :initial => :online do
    state :offline, :searching_for_friend

    event :login do
      transition(:offline => :online)
    end

    event :logout do
      transition(any => :offline)
    end

    event :search_for_friend do
      transition(any => :searching_for_friend, :unless => lambda {|user| user.currently_chatting?})
    end

    event :cancel_searching_for_friend do
      transition(:searching_for_friend => :online)
    end
  end

  def self.purge_invalid_names!(options = {})
    name_attribute = quoted_attribute(:name)
    banned_name_conditions = [
      where("#{name_attribute} ~ ?", "(?:^#{profile_keywords(:banned_names)}$)").where_values.first
    ]

    available_locales = I18n.available_locales.dup
    available_locales.delete(:en)

    available_locales.each do |locale|
      locale_banned_names = "(?:^#{profile_keywords(:banned_names, :locale => locale, :en => false)}$)"
      banned_name_conditions << where(
        "(\"locations\".\"country_code\" = ? AND #{name_attribute} ~ ?)", locale, locale_banned_names
      ).where_values.first
    end

    joins(:location).where(banned_name_conditions.join(" OR ")).update_all("name = NULL")
  end

  def self.online
    where("\"#{table_name}\".\"state\" != ?", "offline")
  end

  def self.logout_users_with_inactive_numbers!(options = {})
    options[:num_last_failed_replies] ||= 5

    # find the most recent replies for a particular user
    recent_replies_subquery = "(#{Reply.where("#{User.quoted_attribute(:user_id, :replies)} = #{User.quoted_attribute(:id)}").reverse_order.limit(options[:num_last_failed_replies]).to_sql}) recent_replies"

    # count the most recent replies that are failed
    num_recently_failed_replies_subquery = "(#{Reply.select('COUNT (*)').from(recent_replies_subquery).where("#{quoted_attribute(:state, :recent_replies)} = 'failed' OR #{quoted_attribute(:state, :recent_replies)} = 'rejected'").to_sql})"

    # logout the users who's most recent replies all failed
    joins(:replies).where(
      "#{num_recently_failed_replies_subquery} = ?", options[:num_last_failed_replies]
    ).where(
      "#{quoted_attribute(:state)} != 'offline'"
    ).uniq.update_all(
      :state => "offline"
    )
  end

  def self.filter_by(params = {})
    super(params).includes(:location)
  end

  def self.filter_params(params = {})
    scope = super.where(params.slice(:gender))
    scope = scope.available if params[:available]
    scope = scope.joins(:location).where(:locations => {:country_code => params[:country_code]}) if params[:country_code]
    scope
  end

  def self.between_the_ages(range)
    where("date_of_birth <= ? AND date_of_birth > ?", range.min.years.ago, range.max.years.ago)
  end

  def self.male
    where(:gender => MALE)
  end

  def self.female
    where(:gender => FEMALE)
  end

  def self.with_date_of_birth
    where("date_of_birth IS NOT NULL")
  end

  def self.without_gender
    where("gender IS NULL")
  end

  def self.available
    where(:active_chat_id => nil).online
  end

  def self.import!(data)
    user_data = JSON.parse(data)
    existing_numbers = Hash[
      User.where(
        :mobile_number => user_data.keys
      ).pluck(
        :mobile_number
      ).map { |mobile_number| [mobile_number, true] }
    ]
    user_data.reject! { |mobile_number, metadata| existing_numbers[mobile_number] }

    user_data.each do |mobile_number, metadata|
      Resque.enqueue(UserCreator, mobile_number, metadata)
    end
  end

  def self.remind!(options = {})
    within_hours(options) do
      limit = options.delete(:limit) || 100

      users_to_remind = not_contacted_recently(
        inactive_timestamp(options)
      ).from_registered_service_providers.online.order(coalesce_last_contacted_at).limit(limit)

      users_to_remind.each do |user_to_remind|
        Resque.enqueue(UserReminderer, user_to_remind.id, options)
      end
    end
  end

  def self.find_friends(options = {})
    within_hours(options) do
      where(:state => "searching_for_friend").find_each do |user|
        enqueue_friend_messenger(user, options)
      end
    end
  end

  def self.matches(user)
    # don't match the user being matched
    match_scope = not_scope(all, :id => user.id, :include_nil => false)

    # exclude existing friends
    match_scope = exclude_existing_friends(user, match_scope)

    # only include available users
    match_scope = match_scope.available

    # order last by location
    match_scope = filter_by_location(user, match_scope)

    # then by age difference
    match_scope = order_by_age_difference(user, match_scope)

    # then by recent activity
    match_scope = order_by_recent_activity(user, match_scope)

    # and first by the user's preferred gender
    match_scope = order_by_preferred_gender(user, match_scope)

    # group by user and make sure the records are not read only
    match_scope.group(self.all_columns).readonly(false)
  end

  def update_profile(info)
    extract(info)
    save
  end

  [:gender, :looking_for].each do |attribute|
    define_method("#{attribute}=") do |value|
      set_gender_related_attribute(attribute, value)
    end
  end

  def contact_me_number
    operator.short_code || twilio_outgoing_number
  end

  def can_call_short_code?
    operator.caller_id.present?
  end

  def caller_id(requesting_api_version)
    adhearsion_twilio_requested?(requesting_api_version) ? (operator.caller_id || twilio_outgoing_number) : twilio_outgoing_number
  end

  def dial_string(requesting_api_version)
    adhearsion_twilio_requested?(requesting_api_version) ? (operator.dial_string(:number_to_dial => mobile_number) || default_pbx_dial_string(:number_to_dial => mobile_number)) : twilio_formatted(mobile_number)
  end

  def find_friends!(options = {})
    self.class.within_hours(options) do
      Chat.activate_multiple!(self, options) if searching_for_friend?
    end
  end

  def female?
    gender == FEMALE
  end

  def male?
    gender == MALE
  end

  def opposite_gender
    if male?
      FEMALE
    elsif female?
      MALE
    end
  end

  def gay?
    gender.present? && gender == looking_for
  end

  def locale
    country_code.to_sym
  end

  def profile_complete?
    profile_complete = true

    PROFILE_ATTRIBUTES.each do |attribute|
      profile_complete = send(attribute).present?
      break unless profile_complete
    end

    profile_complete
  end

  def missing_profile_attributes
    profile_attributes = []

    PROFILE_ATTRIBUTES.each do |attribute|
      profile_attributes << attribute unless send(attribute).present?
    end

    profile_attributes
  end

  def age
    Time.now.utc.year - date_of_birth.year if date_of_birth?
  end

  def age=(value)
    self.date_of_birth = value.nil? ? value : value.years.ago.utc
  end

  def online?
    state != "offline"
  end

  def available?
    online? && (!currently_chatting? || !active_chat.active?)
  end

  def currently_chatting?
    active_chat_id?
  end

  def first_message?
    messages.count == 1
  end

  def screen_id
    (name || screen_name).try(:capitalize)
  end

  def remind!(options = {})
    self.class.within_hours(options) do
      replies.build.send_reminder! unless contacted_recently?(self.class.inactive_timestamp(options))
    end
  end

  def login!
    fire_events(:login)
  end

  def logout!
    if currently_chatting?
      partner = active_chat.partner(self)
      active_chat.deactivate!(:active_user => partner)
    end

    fire_events(:logout)
  end

  def search_for_friend!
    fire_events(:search_for_friend)
    nil
  end

  def matches
    self.class.matches(self)
  end

  def match
    matches.first
  end

  private

  def self.order_by_preferred_gender(user, scope)
    if user.gay?
      # prefer other gays of the same gender
      # then prefer all others of the same gender
      order_scope = where(:looking_for => user.gender).where(:gender => user.looking_for)
    else
      # prefer the opposite sex (if known)
      order_scope = where(:gender => user.opposite_gender) if user.opposite_gender.present?
    end
    scope = order_by_case(scope, order_scope, 2) if order_scope
    scope
  end

  # the age difference where the user's age becomes a factor in the ordering of results
  AGE_BEARING_CUTOFF = 10

  # the age difference on the undesirable side (for straight people),
  # where number of chats is no longer a factor in the ordering of results
  OUT_OF_RANGE_CUTOFF = 2

  # Orders users by a function based on the age difference of the user being matched
  # Orders in ASC order.

  # The function when matching a female with a male is:
  # |a| + 50                   for a <= -K2
  # 0                          for -K2 < a <= K1
  # (|a| - K1)                 for a > K1

  # Similarly, the function when matching a male with a female is:
  # (|a| - K1)                 for a < -K1
  # 0                          for -K1 <= a < K2
  # |a| + 50                   for a >= K2

  # The function when matching males with males or females with females is:
  # (|a| - K1)                 for a < -K1
  # 0                          for -K1 <= a <= K1
  # (|a| - K1)                 for a > K1

  # where:
  # a is the age difference in years between the user being matched and the db user
  # K1 is the age bearing cutoff in years (AGE_BEARING_CUTOFF)
  # K2 is the out of range cutoff in years (OUT_OF_RANGE_CUTOFF)

  # Examples:
  # User being matched is female & the current db user is male:
  # a = 25 (the male db user is 25 years older than the female being matched)
  # K1 = 10
  # 25 - 10 = 15

  # Next db user is male
  # a = 11 (the male db user is 11 years older than the female being matched)
  # K1 = 10
  # 11 - 10 = 1

  # Next db user is male
  # a = -2 (the male db user is 2 years younger than the female being matched)
  # K2 = 2
  # 2 + 50 = 52

  # Next db user is female
  # a = -10 (the female db user is 10 years younger than the female being matched)
  # K1 = 10
  # 0

  def self.order_by_age_difference(user, scope)
    if user.date_of_birth?
      age_diff_in_years = "((DATE('#{user.date_of_birth}') - \"#{table_name}\".\"date_of_birth\")/365)"
      abs_age_diff_in_years = "(ABS(#{age_diff_in_years}))"

      age_bearing_case = "#{abs_age_diff_in_years} > #{AGE_BEARING_CUTOFF}"

      if user.female?
        # when matching with a boy disadvantage those that are too young
        out_of_range_case = "#{age_diff_in_years} <= #{OUT_OF_RANGE_CUTOFF * -1} AND #{table_name}.gender = 'm'"
      elsif user.male?
        # when matching with a girl disadvantage those that are too old
        out_of_range_case = "#{age_diff_in_years} >= #{OUT_OF_RANGE_CUTOFF} AND #{table_name}.gender = 'f'"
      end

      # significantly disadvantage non prefered age group
      out_of_range_clause = "WHEN #{out_of_range_case} THEN #{abs_age_diff_in_years} + 50" if out_of_range_case

      scope.order("CASE WHEN #{age_bearing_case} THEN (#{abs_age_diff_in_years} - #{AGE_BEARING_CUTOFF}) #{out_of_range_clause} ELSE 0 END")
    else
      scope
    end
  end

  # the smallest period in hours of user inactivity
  SMALLEST_INACTIVITY_PERIOD = 0.25

  # the number of inactivity periods
  NUM_INACTIVITY_PERIODS = 13

  # Orders users by recent activity in time periods
  # For example a user with 1 minute inactivity gets
  # the same order value as a person with 14 minutes inactivity

  # ordering is as follows:

  # 0 for last_interaction_at after 0.25 hours ago
  # 1 for last_interaction_at after 0.50 hours ago
  # 2 for last_interaction_at after 1 hour ago
  # 3 for last_interaction_at after 2 hours ago
  # 4 for last_interaction_at after 4 hours ago
  # 5 for last_interaction_at after 8.hours.ago
  # 6 for last_interaction_at after 16.hours.ago
  # 7 for last_interaction_at after 32.hours.ago
  # 8 for last_interaction_at after 64.hours.ago
  # 9 for last_interaction_at after 128.hours.ago
  # 10 for last_interaction_at after 256.hours.ago
  # 11 for last_interaction_at after 512 hours ago
  # 12 for last_interaction_at after 1024 hours ago
  # 13 for last_interaction_at before or equal to 1024 hours ago

  def self.order_by_recent_activity(user, scope)
    # the timestamp to use if the user has had no last_interaction
    # which is the same as 1024 hours ago
    coalesce_timestamp = ((2 ** (NUM_INACTIVITY_PERIODS - 1)) * SMALLEST_INACTIVITY_PERIOD).hours.ago

    inactivity_period = SMALLEST_INACTIVITY_PERIOD
    inactivity_scope = self

    # use the last_interacted_at timestamp to create case statements for recent interaction
    NUM_INACTIVITY_PERIODS.times do
      inactivity_scope = inactivity_scope.where(
        "COALESCE(#{quoted_attribute(:last_interacted_at)}, ?) > ?", coalesce_timestamp, inactivity_period.hours.ago
      )
      inactivity_period *= 2
    end

    # order by the case
    order_by_case(scope, inactivity_scope, NUM_INACTIVITY_PERIODS)
  end

  def self.exclude_existing_friends(user, scope)
    sub_statements = []

    # Select all user id's from users who initated a chat with the reference user
    sub_statements[0] = select("\"#{table_name}\".\"id\"").joins(:chats).where("chats.friend_id" => user.id).to_sql

    # Select all user id's from users were chatted to by the reference user
    sub_statements[1] = select("\"#{table_name}\".\"id\"").joins("INNER JOIN \"chats\" ON \"chats\".\"friend_id\" = \"#{table_name}\".\"id\"").where("chats.user_id" => user.id).to_sql

    # Exclude these users
    sub_statements.each do |sub_statement|
      scope = scope.where("\"#{table_name}\".\"id\" NOT IN (#{sub_statement})")
    end

    scope
  end

  def self.filter_by_location(user, scope)
    # only match users from the same country
    scope = scope.joins(:location).where(:locations => {:country_code => user.country_code})

    # order by distance
    scope.group("locations.latitude, locations.longitude").order(Location.distance_from_sql(user.location))
  end

  def self.not_scope(scope, options)
    include_nil = options.delete(:include_nil)
    attribute = options.keys.first
    quoted_attribute = quoted_attribute(attribute)
    not_sql = "#{quoted_attribute} != ?"
    not_sql << " OR #{quoted_attribute} IS NULL" unless include_nil == false
    scope.where(not_sql, options[attribute])
  end

  def self.from_registered_service_providers
    condition_statements = []
    condition_values = []

    Torasup::Operator.registered_prefixes.each do |prefix|
      condition_statements << "\"#{table_name}\".\"mobile_number\" LIKE ?"
      condition_values << "#{prefix}%"
    end

    where(condition_statements.join(" OR "), *condition_values)
  end

  def self.inactive_timestamp(options = {})
    (options[:inactivity_period] || 5.days).ago
  end

  def self.not_contacted_recently(inactivity_timestamp)
    where("#{coalesce_last_contacted_at} < ?", inactivity_timestamp)
  end

  def self.coalesce_last_contacted_at
    "COALESCE(#{quoted_attribute(:last_contacted_at)}, #{quoted_attribute(:updated_at)})"
  end

  def self.quoted_attribute(attribute, table = nil)
    "\"#{table || table_name}\".\"#{attribute}\""
  end

  def self.within_hours(options = {}, &block)
    do_find = true

    if between = options[:between]
      between = Range.new(*(between.split("..")).map(&:to_i)) if between.is_a?(String)
      now = Time.now
      do_find = (now >= time_at(between.min) && now <= time_at(between.max))
    end

    yield if do_find
  end

  def self.time_at(hour)
    Time.new(Time.now.year, Time.now.month, Time.now.day, hour)
  end

  def self.order_by_case(scope, conditions_scope, else_value)
    order_sql = []

    conditions_scope.where_values.each_with_index do |sql, index|
      sql = sql.to_sql if sql.respond_to?(:to_sql)
      order_sql << "WHEN (#{sql}) THEN #{index}"
    end

    order_sql = "CASE " << order_sql.join(" ") << " ELSE #{else_value} END"

    scope.order(order_sql)
  end

  def self.profile_keywords(*keys)
    options = keys.extract_options!
    options[:en] = true unless (options[:en] == false && options[:locale].present?)

    locales = []
    locales << :en if options[:en]
    locales << options[:locale] if options[:locale]

    all_keywords = []

    keys.each do |key|
      locales.each do |locale|
        locale_keywords = USER_PROFILE_KEYWORDS.try(:[], locale.to_s).try(:[], key.to_s)
        all_keywords |= locale_keywords if locale_keywords.present?
      end
    end
   "(?:#{all_keywords.join('|')})"
  end

  def self.enqueue_friend_messenger(user, options = {})
    Resque.enqueue(FriendMessenger, user.id, options)
  end

  def torasup_number
    @torasup_number ||= Torasup::PhoneNumber.new(mobile_number)
  end

  def operator
    torasup_number.operator
  end

  def cancel_searching_for_friend_if_chatting
    fire_events(:cancel_searching_for_friend) if currently_chatting?
    nil
  end

  def contacted_recently?(inactivity_timestamp)
    last_contacted_timestamp = last_contacted_at || updated_at
    last_contacted_timestamp >= inactivity_timestamp
  end

  def assign_location
    if location.blank?
      build_location
      location.country_code = torasup_number.country_id
      location.address = torasup_number.location.area
    end
  end

  def set_gender_related_attribute(attribute, value)
    value_as_integer = value.to_s.to_i

    if value_as_integer == 1
      value = MALE
    elsif value_as_integer == 2
      value = FEMALE
    end

    write_attribute(attribute, value)
  end

  def looking_for_male?
    looking_for == MALE
  end

  def looking_for_female?
    looking_for == FEMALE
  end

  def extract(info)
    stripped_info = info.dup
    extract_gender_and_looking_for(stripped_info)
    extract_date_of_birth(stripped_info)
    extract_location(stripped_info)
    extract_name(stripped_info)
  end

  def extract_gender_and_looking_for(info)
    return if gay_from?(info)
    gender_question?(info) # removes gender question
    return if extract_gender(info, :explicit_only => true)
    suggests_looking_for?(info) # removes gender preference
    extract_gender(info)
  end

  def gay_from?(info)
    if strip_match!(info, /#{profile_keywords(:gay_boy)}/)
      self.gender = MALE
      self.looking_for = MALE
    elsif(strip_match!(info, /#{profile_keywords(:gay_girl)}/))
      self.gender = FEMALE
      self.looking_for = FEMALE
    end
    gender && looking_for
  end

  def extract_date_of_birth(info)
    match = strip_match!(info, /(?:#{profile_keywords(:i_am)}\s*)?(?<!\d(?:\s|\-|\.|\:)|\d)(?!10|11|12)([1-5][0-9])(?!\s*(?:\d|h(?:o?u?rs?e?)?\b|cm\b|m\b|kg\b|(?:\:|\/)\d+))(?:\s*#{profile_keywords(:years_old)})?/).try(:[], 1)
    self.age = match.to_i if match
  end

  def extract_name(info)
    matches = strip_match!(info, /#{profile_keywords(:name)}(?!\b#{profile_keywords(:banned_names)}\b)(\b[a-z]{2,}\b)(?!\s*\?)/)
    match = matches.try(:[], 2) || matches.try(:[], 1)
    if match
      match.gsub!(/\d+/, "")
      match.strip!
      self.name = match.downcase if match.present?
    end
  end

  def extract_location(info)
    result = location.locate!(info)
    strip_match!(info, /(?:#{profile_keywords(:i_am)}\s*)?#{result}/) if result
  end

  def extract_gender(info, options = {})
    sex = determine_gender(info, options)
    self.gender = sex if sex
  end

  def determine_gender(info, options = {})
    text = options[:explicit_only] ? includes_gender?(info, options).try(:[], 0).to_s : info
    if info_suggests_from_girl?(text, options)
      FEMALE
    elsif info_suggests_from_boy?(text, options)
      MALE
    end
  end

  def suggests_looking_for?(info)
    strip_match!(info, /\b#{gender_keywords(:desired => true)}\b/)
  end

  def includes_gender?(info, options)
    strip_match!(info, /(?:#{profile_keywords(:i_am)}\s+)#{options[:explicit_only] ? "" : "?"}#{gender_keywords}\b/, options)
  end

  def gender_question?(info)
    strip_match!(info, /(?:\b(?:#{gender_keywords(:clues => false)}|m)\s*(?<!f)(?:k?or|a?nd?|r(?:e|u)?y?)\s*(?:#{gender_keywords(:clues => false)}|m)\b)|(?:#{gender_keywords(:clues => false)}\s*\?)/)
  end

  def gender_keywords(*sexes)
    options = sexes.extract_options!
    sexes = [:boy, :girl] if sexes.empty?
    keywords_to_lookup = []
    sexes.each do |sex|
      if options[:desired]
        keywords_to_lookup << "#{sex}friend".to_sym
      else
        keywords_to_lookup << sex
        keywords_to_lookup << "#{sex}_gender_clues".to_sym unless options[:clues] == false
      end
    end
    profile_keywords(*keywords_to_lookup)
  end

  def info_suggests_from?(sex, info, options)
    strip_match!(info, /\b#{gender_keywords(sex)}\b/, options)
  end

  def info_suggests_from_girl?(info, options = {})
    info_suggests_from?(:girl, info, options)
  end

  def info_suggests_from_boy?(info, options = {})
    info_suggests_from?(:boy, info, options)
  end

  def strip_match!(info, regexp, options = {})
    options[:only_first] ? info.sub!(regexp, "") : info.gsub!(regexp, "")
    info.strip!
    $~
  end

  def profile_keywords(*keys)
    self.class.profile_keywords(*keys, :locale => country_code)
  end

  def missing_only?(*attributes)
    missing_profile_attributes == attributes
  end
end
