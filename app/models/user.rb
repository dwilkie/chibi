class User < ActiveRecord::Base
  include Chibi::Analyzable
  include Chibi::Twilio::ApiHelpers
  include Chibi::Communicable::HasCommunicableResources

  DEFAULT_WITHOUT_RECENT_INTERACTION_MONTHS = 1
  DEFAULT_REMIND_MAX = 100
  DEFAULT_MAX_REMIND_FREQUENCY_DAYS = 5
  DEFAULT_USER_HOURS_MIN = 8
  DEFAULT_USER_HOURS_MAX = 20

  include AASM

  has_communicable_resources :phone_calls, :messages, :replies

  MALE = "m"
  FEMALE = "f"
  MINIMUM_MOBILE_NUMBER_LENGTH = 10

  has_one :location, :autosave => true

  # describes initiated chats i.e. chat initiated by user
  has_many :chats
  has_many :friends, :through => :chats

  # decribes accepted friendships i.e. chat initiated by accepted friend
  has_many :participating_chats, :class_name => "Chat", :foreign_key => "friend_id"
  has_many :chat_friends, :through => :participating_chats, :source => :user

  has_many :charge_requests

  belongs_to :active_chat, :class_name => "Chat"
  belongs_to :latest_charge_request, :class_name => "ChargeRequest"

  validates :mobile_number,
            :presence => true,
            :length => { :minimum => MINIMUM_MOBILE_NUMBER_LENGTH },
            :phony_plausible => true

  validates :location, :screen_name, :presence => true

  validates :gender, :inclusion => {:in => [MALE, FEMALE], :allow_nil => true}
  validates :looking_for, :inclusion => {:in => [MALE, FEMALE], :allow_nil => true}
  validates :age, :inclusion => {:in => 10..99, :allow_nil => true}

  before_validation(:on => :create) do
    self.screen_name = Faker::Name.first_name.downcase unless screen_name.present?
    if mobile_number.present?
      set_operator_name
      assign_location
    end
  end

  before_save :cancel_searching_for_friend_if_chatting

  delegate :city, :country_code, :to => :location, :allow_nil => true
  delegate :deactivate!, :to => :active_chat, :prefix => true, :allow_nil => true

  aasm :column => :state, :whiny_transitions => false do
    state :online, :initial => true
    state :offline
    state :searching_for_friend

    event :login do
      transitions(:from => :offline, :to => :online)
    end

    event :logout, :after_commit => :deactivate_chats! do
      transitions(:to => :offline)
    end

    event :search_for_friend do
      transitions(:to => :searching_for_friend, :unless => :currently_chatting?)
    end

    event :cancel_searching_for_friend do
      transitions(:from => :searching_for_friend, :to => :online)
    end
  end

  def self.online
    where.not(:state => "offline")
  end

  def self.by_id(user)
    where(:id => user.id)
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
    where("date_of_birth <= ? AND date_of_birth > ?", range.min.years.ago.to_date, range.max.years.ago.to_date)
  end

  def self.with_inactive_numbers(options = {})
    options[:num_last_failed_replies] ||= 5

    # find the most recent replies for a particular user
    recent_replies_subquery = "(#{Reply.where("#{User.quoted_attribute(:user_id, :replies)} = #{User.quoted_attribute(:id)}").reverse_order.limit(options[:num_last_failed_replies]).to_sql}) recent_replies"

    # count the most recent replies that are failed
    num_recently_failed_replies_subquery = "(#{Reply.select('COUNT (*)').from(recent_replies_subquery).where("#{quoted_attribute(:state, :recent_replies)} = 'failed' OR #{quoted_attribute(:state, :recent_replies)} = 'rejected'").to_sql})"

    # logout the users who's most recent replies all failed
    joins(:replies).where(
      "#{num_recently_failed_replies_subquery} = ?", options[:num_last_failed_replies]
    ).uniq
  end

  def self.male
    where(:gender => MALE)
  end

  def self.female
    where(:gender => FEMALE)
  end

  def self.with_date_of_birth
    where.not(:date_of_birth => nil)
  end

  def self.without_gender
    where(:gender => nil)
  end

  def self.available
    online.not_currently_chatting
  end

  def self.not_currently_chatting
    where(:active_chat_id => nil)
  end

  def self.remind!
    return if out_of_user_hours?
    users_to_remind = not_contacted_recently.from_registered_service_providers.online.order(coalesce_last_contacted_at).limit(remind_max)

    users_to_remind.each do |user_to_remind|
      UserRemindererJob.perform_later(user_to_remind.id)
    end
  end

  def self.find_friends!
    return if out_of_user_hours?
    searching_for_friend.find_each do |user|
      FriendMessengerJob.perform_later(user.id)
    end
  end

  def self.matches(user)
    # don't match the user being matched
    match_scope = not_scope(all, :id => user.id, :include_nil => false)

    # exclude existing friends
    match_scope = exclude_existing_friends(user, match_scope)

    # only include available users
    match_scope = match_scope.available

    # order first by the user's preferred gender
    match_scope = order_by_preferred_gender(user, match_scope)

    # then by recent activity
    match_scope = order_by_recent_activity(user, match_scope)

    # then by age difference
    match_scope = order_by_age_difference(user, match_scope)

    # order last by location
    match_scope = filter_by_location(user, match_scope)

    # group by user and make sure the records are not read only
    match_scope.group(self.all_columns).readonly(false)
  end

  def update_profile(info)
    extract(info)
    save
  end

  def charge!(requester)
    return true if !chargeable?
    if latest_charge_request
      if latest_charge_request.successful?
        if latest_charge_request.updated_at < 24.hours.ago
          create_charge_request!(requester)
        else
          true
        end
      elsif latest_charge_request.failed?
        create_charge_request!(requester, true)
        false
      else
        (latest_charge_request.errored? && create_charge_request!(requester)) || latest_charge_request.slow?
      end
    else
      create_charge_request!(requester)
    end
  end

  def chargeable?
    operator.chargeable
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
    adhearsion_twilio_requested?(requesting_api_version) ? (operator.dial_string(:number_to_dial => mobile_number, :dial_string_number_prefix => operator.dial_string_number_prefix, :voip_gateway_host => operator.voip_gateway_host) || default_pbx_dial_string(:number_to_dial => mobile_number)) : twilio_formatted(mobile_number)
  end

  def find_friends!
    Chat.activate_multiple!(self, :notify => true, :notify_no_match => false) if searching_for_friend?
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

  def age
    Time.current.year - date_of_birth.year if date_of_birth?
  end

  def age=(value)
    self.date_of_birth = value.nil? ? value : value.years.ago
  end

  def online?
    state != "offline"
  end

  def available?(options = {})
    online? && (!currently_chatting? || !active_chat.active?)
  end

  def currently_chatting?
    active_chat.present?
  end

  def screen_id
    (name || screen_name).try(:capitalize)
  end

  def deactivate_chats!
    active_chat_deactivate!(:activate_new_chats => true)
  end

  def remind!
    replies.build.send_reminder! if !contacted_recently?
  end

  def reply_not_enough_credit!
    replies.build.not_enough_credit!
  end

  def matches
    self.class.matches(self)
  end

  def match
    matches.first
  end

  def assign_location(address = nil)
    unless location
      build_location
      location.country_code = torasup_number && torasup_number.country_id
      location.address = address.present? ? address : torasup_number && torasup_number.location.area
    end
  end

  def operator
    torasup_number && torasup_number.operator
  end

  private

  def create_charge_request!(requester, notify_requester = false)
    self.latest_charge_request = ChargeRequest.new(
      :requester => requester,
      :notify_requester => notify_requester,
      :operator => operator.id
    )
    charge_requests << latest_charge_request
    save!
  end

  def self.by_operator_joins
    joins(:location)
  end

  def self.by_operator_name_joins_conditions(options)
    by_operator_name_conditions(options)
  end

  def self.order_by_preferred_gender(user, scope)
    if user.gay?
      # prefer other gays of the same gender
      # then prefer all others of the same gender
      order_scope = where("looking_for = ?", user.gender).where("gender = ?", user.looking_for)
    else
      # prefer the opposite sex (if known)
      order_scope = where("gender = ?", user.opposite_gender) if user.opposite_gender.present?
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
        "COALESCE(#{quoted_attribute(:last_interacted_at)}, ?) > ?",
        coalesce_timestamp,
        inactivity_period.hours.ago
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
    values = []

    Torasup::Operator.registered.each do |country_code, operators|
      country_condition = "\"#{Location.table_name}\".\"country_code\" = ?"
      values << country_code
      operator_conditions = []
      operators.each do |operator_id, operator_metadata|
        operator_conditions << "\"#{table_name}\".\"operator_name\" = ?"
        values << operator_id
      end
      operator_condition = "(#{operator_conditions.join(' OR ')})"
      condition_statements << "(#{country_condition} AND #{operator_condition})"
    end

    joins(:location).where(condition_statements.join(' OR '), *values)
  end

  def self.not_contacted_recently
    where("#{coalesce_last_contacted_at} < ?", max_remind_frequency_days.ago)
  end

  def self.coalesce_last_contacted_at
    "COALESCE(#{quoted_attribute(:last_contacted_at)}, #{quoted_attribute(:updated_at)})"
  end

  def self.quoted_attribute(attribute, table = nil)
    "\"#{table || table_name}\".\"#{attribute}\""
  end

  def self.out_of_user_hours?
    current_hour = Time.current.hour
    current_hour < user_hours_min || current_hour >= user_hours_max
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

  def self.without_recent_interaction
    where(
      "COALESCE(\"#{table_name}\".\"last_interacted_at\", ?) < ?",
      without_recent_interaction_months.ago,
      without_recent_interaction_months.ago
    )
  end

  def self.without_recent_interaction_months
    (Rails.application.secrets[:user_without_recent_interaction_months] || DEFAULT_WITHOUT_RECENT_INTERACTION_MONTHS).to_i.months
  end

  def self.remind_max
    (Rails.application.secrets[:user_remind_max] || DEFAULT_REMIND_MAX).to_i
  end

  def self.max_remind_frequency_days
    (Rails.application.secrets[:user_max_remind_frequency_days] || DEFAULT_MAX_REMIND_FREQUENCY_DAYS).to_i.days
  end

  def self.user_hours_min
    (Rails.application.secrets[:user_hours_min] || DEFAULT_USER_HOURS_MIN).to_i
  end

  def self.user_hours_max
    (Rails.application.secrets[:user_hours_max] || DEFAULT_USER_HOURS_MAX).to_i
  end

  def set_operator_name
    self.operator_name = operator && operator.id
  end

  def torasup_number
    return @torasup_number if @torasup_number
    @torasup_number = Torasup::PhoneNumber.new(mobile_number) if valid_mobile_number?
  end

  def cancel_searching_for_friend_if_chatting
    cancel_searching_for_friend! if currently_chatting?
    nil
  end

  def contacted_recently?
    (last_contacted_at || updated_at) >= self.class.max_remind_frequency_days.ago
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

  def valid_mobile_number?
    Phony.plausible?(mobile_number)
  end
end
