# encoding: utf-8

class User < ActiveRecord::Base
  include Analyzable
  include Communicable::HasCommunicableResources
  include TwilioHelpers

  PROFILE_ATTRIBUTES = [:name, :date_of_birth, :gender, :city, :looking_for]
  DEFAULT_ALTERNATE_LOCALE = "en"
  MALE = "m"
  FEMALE = "f"
  BISEXUAL = "e"
  PROBABLE_GENDER = MALE
  PROBABLE_LOOKING_FOR = FEMALE

  has_one :location, :autosave => true

  # describes initiated chats i.e. chat initiated by user
  has_many :chats
  has_many :friends, :through => :chats

  # decribes accepted friendships i.e. chat initiated by accepted friend
  has_many :participating_chats, :class_name => "Chat", :foreign_key => "friend_id"
  has_many :chat_friends, :through => :participating_chats, :source => :user

  belongs_to :active_chat, :class_name => "Chat"

  validates :mobile_number, :presence => true, :uniqueness => true, :length => {:minimum => 9}
  validates :location, :screen_name, :presence => true

  validates :gender, :inclusion => {:in => [MALE, FEMALE], :allow_nil => true}
  validates :looking_for, :inclusion => {:in => [MALE, FEMALE, BISEXUAL], :allow_nil => true}
  validates :age, :inclusion => {:in => 10..99, :allow_nil => true}

  before_validation(:on => :create) do
    self.screen_name = Faker::Name.first_name.downcase unless screen_name.present?
  end

  after_initialize :assign_location

  delegate :city, :country_code, :address, :address=, :locate!, :to => :location, :allow_nil => true

  def self.filter_by(params = {})
    super(params).includes(:location)
  end

  def self.filter_params(params = {})
    scope = super.where(params.slice(:gender))
    scope = exclude_unavailable(scope) if params[:available]
    scope
  end

  def self.remind!(options = {})
    inactivity_period = options[:inactivity_period] || 5.days
    limit = options[:limit] || 100
    since = inactivity_period.ago

    users_to_remind = without_recent_interaction(since).where(:online => true).limit(limit)

    users_to_remind.each do |user_to_remind|
      user_to_remind.remind!
    end
  end

  def self.matches(user)
    # don't match the user being matched
    match_scope = not_scope(scoped, :id => user.id, :include_nil => false)

    # If the user is a male don't match him with users looking for females
    # If the user is female, don't match her with users looking for males
    opposite_gender = user.opposite_gender
    match_scope = not_scope(match_scope, :looking_for => opposite_gender) if opposite_gender.present?

    # If the user looking for a male don't match them with females
    # If the user is looking for a female don't match them with males
    opposite_looking_for = user.opposite_looking_for
    match_scope = not_scope(match_scope, :gender => opposite_looking_for) if opposite_looking_for.present?

    # exclude existing friends
    match_scope = exclude_existing_friends(user, match_scope)

    # only include available users
    match_scope = exclude_unavailable(match_scope)

    # match users from registered service providers together
    # and users from unregistered service providers together
    match_scope = match_users_from_registered_service_providers(user, match_scope)

    if user.bisexual?
      # he/she doesn't care about the other user's gender so don't order by it
      match_scope = order_by_preferred(
        :looking_for, user, match_scope, :other => BISEXUAL, :preferred => true
      )
    else
      # order by the user's preferred gender first unless its unknown in which case order first
      # by users who's preferred gender is the user's gender
      preferred_attributes = [
        {:gender => {}}, {:looking_for => {:other => BISEXUAL, :preferred => user.bisexual?}}
      ]
      preferred_attributes.reverse! if user.looking_for.nil? && user.gender.present?
      preferred_attributes.each do |preferred_attribute|
        attribute = preferred_attribute.keys.first
        options = preferred_attribute[attribute]
        match_scope = order_by_preferred(attribute, user, match_scope, options)
      end
    end

    # then by recent activity
    match_scope = order_by_recent_activity(user, match_scope)

    # then by age difference and number of initiated chats
    match_scope = order_by_age_difference_and_initiated_chats(user, match_scope)

    # then by location
    match_scope = filter_by_location(user, match_scope)

    # make sure the records are not read only
    match_scope.readonly(false)
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

  def locale
    raw_locale = read_attribute(:locale)
    raw_locale ? raw_locale.to_s.downcase.to_sym : country_code.to_sym
  end

  def short_code
    SERVICE_PROVIDER_PREFIXES[country_code].try(:[], number_prefix)
  end

  def local_number
    split_number = split_mobile_number
    split_number.shift
    split_number.join
  end

  def twilio_number
    twilio_outgoing_number(:for => split_mobile_number)
  end

  def female?
    gender == 'f'
  end

  def male?
    gender == 'm'
  end

  def bisexual?
    looking_for == BISEXUAL
  end

  def opposite_gender
    if male?
      FEMALE
    elsif female?
      MALE
    end
  end

  def opposite_looking_for
    if looking_for_male?
      FEMALE
    elsif looking_for_female?
      MALE
    end
  end

  def probable_gender
    gender.present? ? gender : (opposite_looking_for || PROBABLE_GENDER)
  end

  def probable_looking_for
    looking_for.present? ? looking_for : (opposite_gender || PROBABLE_LOOKING_FOR)
  end

  def hetrosexual?
    (male? && looking_for_female?) || (female? && looking_for_male?)
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

  def available?(in_chat = nil)
    online? && (!currently_chatting? || active_chat == in_chat)
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

  def remind!
    replies.build.send_reminder!
  end

  def login!
    update_attributes!(:online => true) unless online?
  end

  def logout!(options = {})
    if currently_chatting?
      partner = active_chat.partner(self)
      notify = partner if options[:notify_chat_partner]
      active_chat.deactivate!(:active_user => partner, :notify => notify)
    end

    update_attributes!(:online => false)
    replies.build.logout!(partner) if options[:notify]
  end

  def welcome!
    replies.build.welcome!
  end

  def update_locale!(locale, options = {})
    updating_to_same_locale = (locale.to_s.to_sym == self.locale)

    if (locale == DEFAULT_ALTERNATE_LOCALE || locale == country_code) && !updating_to_same_locale
      update_successful = update_attributes!(:locale => locale)
      replies.last_delivered.try(:deliver_alternate_translation!) if options[:notify]
      update_successful
    else
      updating_to_same_locale
    end
  end

  def matches
    self.class.matches(self)
  end

  def match
    matches.first
  end

  private

  def self.order_by_preferred(preferred_attribute, user, scope, options = {})
    complimentary_attribute = preferred_attribute == :gender ? :looking_for : :gender
    probable_complimentary_value = user.send("probable_#{complimentary_attribute}")

    preferred_values = [probable_complimentary_value]
    preferred_values << options[:other] if options[:other]
    preferred_values.reverse! if options[:preferred]
    preferred_values << nil

    preferred_value_scope = self

    preferred_values.each do |preferred_value|
      preferred_value_scope = preferred_value_scope.where(preferred_attribute => preferred_value)
    end

    order_by_case(scope, preferred_value_scope, preferred_values.count)
  end

  # the age difference where the user's age becomes a factor in the ordering of results
  AGE_BEARING_CUTOFF = 10

  # the age difference on the undesirable side (for straight people),
  # where number of chats is no longer a factor in the ordering of results
  OUT_OF_RANGE_CUTOFF = 2

  # Orders users by a function based on the age difference of the user being matched
  # and the amount of chats the user has initiated. Orders in ASC order.

  # The function when matching a female with a male is:
  # |a| + 100                  for a <= -K2
  # 1/(c + 1)                  for -K2 < a <= K1
  # (|a| - K1 + 1)^2 / (c + 1) for a > K1

  # Similarly, the function when matching a male with a female is:
  # (|a| - K1 + 1)^2 / (c + 1) for a < -K1
  # 1/(c + 1)                  for -K1 <= a < K2
  # |a| + 100                  for a >= K2

  # The function when matching males with males or females with females is:
  # (|a| - K1 + 1)^2 / (c + 1) for a < -K1
  # 1/(c + 1)                  for -K1 <= a <= K1
  # (|a| - K1 + 1)^2 / (c + 1) for a > K1

  # where:
  # a is the age difference in years between the user being matched and the db user
  # c is the number of chats the db user has initiated
  # K1 is the age bearing cutoff in years (AGE_BEARING_CUTOFF)
  # K2 is the out of range cutoff in years (OUT_OF_RANGE_CUTOFF)

  # Examples:
  # User being matched is female & the current db user is male:
  # a = 25 (the male db user is 25 years older than the female being matched)
  # c = 50 (the male db user has initiated 50 chats)
  # K1 = 10
  # (25 - 10 + 1)^2 / (50 + 1) = 25.4

  # Next db user is male
  # a = 11 (the male db user is 11 years older than the female being matched)
  # c = 5  (the male db user has initiated 0 chats)
  # K1 = 10
  # (11 - 10 + 1)^2 / (0 + 1) = 4

  # Next db user is male
  # a = -2 (the male db user is 2 years younger than the female being matched)
  # K2 = 2
  # 2 + 100 = 102

  # Next db user is female
  # a = -10 (the female db user is 10 years younger than the female being matched)
  # c = 1 (the female db user has initiated 1 chat)
  # K1 = 10
  # 1/(1 + 1) = 0.5

  def self.order_by_age_difference_and_initiated_chats(user, scope)
    # join all users on intitated chats
    scope = scope.joins("LEFT OUTER JOIN \"chats\" AS \"initiated_chats\" ON \"initiated_chats\".\"user_id\" = \"#{table_name}\".\"id\"")

    age_diff_in_years = "((DATE('#{user.date_of_birth}') - \"#{table_name}\".\"date_of_birth\")/365)"
    abs_age_diff_in_years = "(ABS(#{age_diff_in_years}))"
    chat_factor = "(count(\"initiated_chats\".*) + 1)"

    # Use a symmetrical age difference for when age starts to matter for non hetrosexual users
    age_bearing_case = "#{abs_age_diff_in_years} >= #{AGE_BEARING_CUTOFF}" unless user.hetrosexual?

    if user.female?
      # prefer older guys
      age_bearing_case ||= "#{age_diff_in_years} > #{AGE_BEARING_CUTOFF}"
      out_of_range_case = "#{age_diff_in_years} <= #{OUT_OF_RANGE_CUTOFF * -1} AND #{table_name}.gender = 'm'"
    elsif user.male?
      # prefer younger girls
      age_bearing_case ||= "#{age_diff_in_years} < #{AGE_BEARING_CUTOFF * -1}"
      out_of_range_case = "#{age_diff_in_years} >= #{OUT_OF_RANGE_CUTOFF} AND #{table_name}.gender = 'f'"
    end

    # significantly disadvantage non prefered age group
    out_of_range_clause = "WHEN #{out_of_range_case} THEN #{abs_age_diff_in_years} + 100" if out_of_range_case

    order_sql = user.date_of_birth? ? "CASE WHEN #{age_bearing_case} THEN (POWER(#{abs_age_diff_in_years} - #{AGE_BEARING_CUTOFF} + 1, 2)) * 1.0/#{chat_factor} #{out_of_range_clause} ELSE 1.0/#{chat_factor} END" : "1.0/#{chat_factor}"

    scope.order(order_sql)
  end

  # the smallest period in hours of user inactivity
  SMALLEST_INACTIVITY_PERIOD = 0.25

  # the number of inactivity periods
  NUM_INACTIVITY_PERIODS = 5

  # Orders users by recent activity in time periods
  # For example a user with 1 minute inactivity gets
  # the same order value as a person with 14 minutes inactivity

  # ordering is as follows:

  # 0 for updated_at > 0.25 hours ago
  # 1 for updated_at > 0.50 hours ago
  # 2 for updated_at > 1 hour ago
  # 3 for updated_at > 2 hours ago
  # 4 for updated_at > 4 hours ago
  # 5 for updated_at <= 4 hours ago

  def self.order_by_recent_activity(user, scope)
    inactivity_period = SMALLEST_INACTIVITY_PERIOD
    inactivity_scope = self

    NUM_INACTIVITY_PERIODS.times do
      inactivity_scope = inactivity_scope.where("#{table_name}.updated_at > ?", inactivity_period.hours.ago)
      inactivity_period *= 2
    end

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

    # add group by clause for every column that is being selected
    # so Postgres doesn't complain. This can be removed after upgrading to Postgres 9.1
    scope = scope.group(self.all_columns).group(Location.all_columns)

    # order by distance
    scope.order(Location.distance_from_sql(user.location))
  end

  def self.not_scope(scope, options)
    include_nil = options.delete(:include_nil)
    attribute = options.keys.first
    quoted_attribute = quoted_attribute(attribute)
    not_sql = "#{quoted_attribute} != ?"
    not_sql << " OR #{quoted_attribute} IS NULL" unless include_nil == false
    scope.where(not_sql, options[attribute])
  end

  def self.match_users_from_registered_service_providers(user, scope)
    # skip this restriction if the user is from a country with no service providers
    # another restriction says they can't be matched with users from other countries anyway
    service_providers_in_users_location = SERVICE_PROVIDER_PREFIXES[user.country_code]
    return scope unless service_providers_in_users_location

    # for the following examples '012' and '097' are prefixes of a registered service provider

    # if the user being matched has a short code (i.e. there is a registered service provider for his number)
    # match him with other users that have registered service providers. This prevents users
    # who are coming through testing gateways being matched with users coming from registered service providers
    # e.g. users.mobile_number LIKE 85512% OR users.mobile_number LIKE 85597%

    # on the other hand if the user being matched has no short code
    # (i.e. there is no registered service provider for his number)
    # don't match him with users belong to a registered service provider
    # e.g. users.mobile_number NOT LIKE 85512% OR users.mobile_number NOT LIKE 85597%

    if user.short_code.present?
      condition_sql = " OR "
    else
      negation_sql = "NOT "
      condition_sql = " AND "
    end

    condition_statements = []
    condition_values = []

    service_providers_in_users_location.each do |prefix, short_code|
      condition_statements << "\"#{table_name}\".\"mobile_number\" #{negation_sql}LIKE ?"
      condition_values << "#{international_dialing_code(user.mobile_number)}#{prefix}%"
    end

    scope.where(condition_statements.join(condition_sql), *condition_values)
  end

  def self.without_recent_interaction(since)
    where_values = []

    scope = scoped

    COMMUNICABLE_RESOURCES.each do |communicable_resource|
      sub_statement = reflect_on_association(communicable_resource).klass.users_latest.to_sql
      scope = scope.where("(#{sub_statement}) < ? OR (#{sub_statement}) IS NULL", since)
    end

    scope
  end

  def self.exclude_unavailable(scope)
    scope.where(:active_chat_id => nil, :online => true)
  end

  def self.split_mobile_number(number)
    Phony.split(number.to_i.to_s)
  end

  def self.international_dialing_code(number)
    split_mobile_number(number).first
  end

  def self.quoted_attribute(attribute)
    "\"#{table_name}\".\"#{attribute}\""
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

  def international_dialing_code
    self.class.international_dialing_code(mobile_number)
  end

  def split_mobile_number
    self.class.split_mobile_number(mobile_number)
  end

  def number_prefix
    local_number[0..1]
  end

  def assign_location
    build_location(
      :country_code => DIALING_CODES[international_dialing_code].try(:downcase)
    ) unless persisted? || location.present?
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
    return if name_given?(info)

    stripped_info = info.dup

    profile_complete = profile_complete?
    extract_name(stripped_info, profile_complete)

    unless profile_complete || missing_only?(:name)
      first_word = strip_match!(stripped_info, /\w+/, :only_first => true).try(:[], 0)
      extract_profile_without_location(stripped_info, profile_complete)

      if missing_only?(:name) || (missing_only?(:name, :city) && changed?)
        self.name = first_word
        extract_location(stripped_info, profile_complete)
        return
      else
        discard_changes
      end
    end

    extract_profile(info, profile_complete)
  end

  def extract_profile(info, profile_complete)
    stripped_info = info.dup

    extract_profile_without_location(stripped_info, profile_complete)
    extract_location(stripped_info, profile_complete)
  end

  def extract_profile_without_location(info, profile_complete)
    extract_gender_and_looking_for(info, profile_complete)
    extract_date_of_birth(info, profile_complete)
    extract_name(info, profile_complete)
  end

  def name_given?(info)
    if missing_only?(:name)
      message_words = info.split(/\s+/)
      if message_words.count == 1
        self.name = message_words.first
      end
    end
  end

  def extract_gender_and_looking_for(info, force_update)
    unless includes_gender_and_looking_for?(info)
      extract_looking_for(info, :include_shared_gender_words => gender.present? && !force_update)
      extract_gender(info, force_update)
    end
  end

  def extract_date_of_birth(info, force_update)
    match = strip_match!(info, /(?:#{profile_keywords(:i_am)}\s*)?(?<!\d(?:\s|\-|\.|\:)|\d)([1-5][0-9])(?!\s*(?:\d|h(?:o?u?rs?)?\b|cm\b|m\b|kg\b|\:\d+))(?:\s*#{profile_keywords(:years_old)})?/).try(:[], 1)
    self.age = match.to_i if match && (force_update || date_of_birth.nil?)
  end

  def extract_name(info, force_update)
    matches = strip_match!(info, /#{profile_keywords(:name)}/)
    match = matches.try(:[], 2) || matches.try(:[], 1)
    self.name = match.downcase if match && (force_update || name.nil?)
  end

  def extract_location(info, force_update)
    if force_update || city.nil?
      self.address = info
      locate!
    end
  end

  def includes_gender_and_looking_for?(info)
    tmp_info = info.dup
    if sex = determine_gender(tmp_info, :only_first => true)
      if wants = determine_looking_for(tmp_info, :use_only_shared_gender_words => true)
        # we have the sex and looking for already so remove all references to
        # gender and looking for from the message
        unless gender_question?(info)
          determine_gender(info, :only_first => true)
          determine_looking_for(info, :include_shared_gender_words => true)
          self.gender = sex
          self.looking_for = wants
        end
        info = tmp_info
      end
    end
  end

  def extract_looking_for(info, options = {})
    user_looking_for = determine_looking_for(info, options)
    self.looking_for = user_looking_for if user_looking_for
  end

  def extract_gender(info, force_update)
    sex = determine_gender(info)
    self.gender = sex if sex && (gender.nil? || force_update)
  end

  def determine_looking_for(info, options = {})
    if info_suggests_looking_for_girl?(info, options)
      FEMALE
    elsif info_suggests_looking_for_boy?(info, options)
      MALE
    elsif !options[:use_only_shared_gender_words] && info_suggests_looking_for_friend?(info)
      BISEXUAL
    end
  end

  def determine_gender(info, options = {})
    text = options[:only_first] ? includes_gender?(info, options).try(:[], 0).to_s : info
    if info_suggests_from_girl?(text, options)
      FEMALE
    elsif info_suggests_from_boy?(text, options)
      MALE
    end
  end

  def info_suggests_looking_for?(sex, info, options)
    looking_for = "#{sex}friend"
    could_mean = "could_mean_#{sex}_or_#{looking_for}"

    if options[:include_shared_gender_words]
      regexp = /\b#{profile_keywords(could_mean, looking_for)}\b/
    elsif options[:use_only_shared_gender_words]
      regexp = /\b#{profile_keywords(could_mean)}\b/
    else
      regexp = /\b#{profile_keywords(looking_for)}\b/
    end
    strip_match!(info, regexp)
  end

  def info_suggests_looking_for_girl?(info, options = {})
    info_suggests_looking_for?(:girl, info, options)
  end

  def info_suggests_looking_for_boy?(info, options = {})
   info_suggests_looking_for?(:boy, info, options)
  end

  def info_suggests_looking_for_friend?(info)
    strip_match!(info, /\b#{profile_keywords(:friend)}\b/)
  end

  def includes_gender?(info, options)
    strip_match!(info, /(?:m|i'm)?\s*a?\b#{gender_keywords}\b/, options)
  end

  def gender_question?(info)
    strip_match!(info, /\b#{gender_keywords}\s*(?<!f)or\s*#{gender_keywords}\b/)
  end

  def gender_keywords
    profile_keywords(:could_mean_boy_or_boyfriend, :boy, :could_mean_girl_or_girlfriend, :girl)
  end

  def info_suggests_from?(sex, info, options)
    could_mean = "could_mean_#{sex}_or_#{sex}friend"
    strip_match!(info, /\b#{profile_keywords(sex, could_mean)}\b/, options)
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
    all_keywords = []
    keys.each do |key|
      english_keywords = USER_PROFILE_KEYWORDS["en"][key.to_s]
      localized_keywords = USER_PROFILE_KEYWORDS.try(:[], country_code).try(:[], key.to_s)
      all_keywords |= localized_keywords.present? ? (english_keywords | localized_keywords) : english_keywords
    end
   "(?:#{all_keywords.join('|')})"
  end

  def missing_only?(*attributes)
    missing_profile_attributes == attributes
  end

  def discard_changes
    changes.each do |attribute, change|
      if PROFILE_ATTRIBUTES.include?(attribute.to_sym)
        self.send("#{attribute}=", change.first)
      end
    end
  end
end
