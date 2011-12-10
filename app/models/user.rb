class User < ActiveRecord::Base
  has_one :location

  has_many :messages, :through => :subscriptions
  has_many :replies,  :through => :subscriptions

  # describes initiated chats i.e. chat initiated by user
  has_many :chats
  has_many :friends, :through => :chats

  # decribes accepted friendships i.e. chat initiated by accepted friend
  has_many :participating_chats, :class_name => "Chat", :foreign_key => "friend_id"
  has_many :chat_friends, :through => :participating_chats, :source => :user

  belongs_to :active_chat, :class_name => "Chat"

  validates :mobile_number, :presence => true, :uniqueness => true
  validates :location, :presence => true
  validates :username, :uniqueness => true

  before_validation(:on => :update) do
    self.username = name.gsub(/\s+/, "") << id.to_s if attribute_present?(:name) && persisted?
  end

  PROFILE_ATTRIBUTES = ["name", "date_of_birth", "location", "gender", "looking_for"]

  # the age difference where the user's age becomes a factor in the ordering of results
  AGE_BEARING_CUTOFF = 6

  # the age difference on the undesirable side (for straight people),
  # where number of chats is no longer a factor in the ordering of results
  OUT_OF_RANGE_CUTOFF = 2

  def self.matches(user)
    # don't match the user being matched
    match_scope = scoped.where("\"#{table_name}\".\"id\" != ?", user.id)

    # if the user's gender is unknown and their looking for preference
    # is also unknown, only match them with other users that are
    # in the same situation
    if !user.gender? && !user.looking_for?
      match_scope = match_scope.where(:gender => nil, :looking_for => nil)
    else
      # if the user's gender is known, match him/her with other users
      # that are looking for his/her gender or other users that explicitly indifferent
      match_scope = user.gender? ? match_scope.where("\"#{table_name}\".\"looking_for\" = ? OR \"#{table_name}\".\"looking_for\" = ?", user.gender, "e") : match_scope.where(:gender => user.looking_for, :looking_for => nil)

      # if the user is indifferent about the gender they are seeking
      # match them with either males or females (but not unknowns) otherwise
      # match them with the gender they are seeking
      match_scope = user.looking_for == "e" ? match_scope.where("\"#{table_name}\".\"gender\" IS NOT NULL") : match_scope.where(:gender => user.looking_for)
    end

    # exclude existing friends
    match_scope = exclude_existing_friends(user, match_scope)

    # exclude currently chatting users
    match_scope = match_scope.where(:active_chat_id => nil)

    # order first by location
    match_scope = filter_by_location(user, match_scope)

    # then by age difference and number of initiated chats
    order_by_age_difference_and_initiated_chats(user, match_scope)
  end

  def female?
    gender == 'f'
  end

  def male?
    gender == 'm'
  end

  def hetrosexual?
    (gender == 'm' && looking_for == 'f') || (gender == 'f' && looking_for == 'm')
  end

  def profile_complete?
    profile_complete = true

    PROFILE_ATTRIBUTES.each do |attribute|
      profile_complete = send(attribute).present?
      break unless profile_complete
    end

    profile_complete
  end

  def age
    Time.now.utc.year - date_of_birth.utc.year if date_of_birth?
  end

  def age=(value)
    self.date_of_birth = value.nil? ? value : value.years.ago.utc
  end

  def currently_chatting?
    active_chat_id?
  end

  private

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
      age_bearing_case ||= "#{age_diff_in_years} >= #{AGE_BEARING_CUTOFF}"
      out_of_range_case = "#{age_diff_in_years} <= #{OUT_OF_RANGE_CUTOFF * -1} AND #{table_name}.gender = 'm'"
    elsif user.male?
      # prefer younger girls
      age_bearing_case ||= "#{age_diff_in_years} <= #{AGE_BEARING_CUTOFF * -1}"
      out_of_range_case = "#{age_diff_in_years} >= #{OUT_OF_RANGE_CUTOFF} AND #{table_name}.gender = 'f'"
    end

    # significantly disadvantage non prefered age group
    out_of_range_clause = "WHEN #{out_of_range_case} THEN #{abs_age_diff_in_years} + 100" if out_of_range_case

    order_sql = user.date_of_birth? ? "CASE WHEN #{age_bearing_case} THEN (POWER(#{abs_age_diff_in_years} - 5, 2)) * 1.0/#{chat_factor} #{out_of_range_clause} ELSE 1.0/#{chat_factor} END" : "1.0/#{chat_factor}"

    scope.order(order_sql)
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
    scope = scope.joins(:location).where(:locations => {:country_code => user.location.country_code})

    # add group by clause so Postgres doesn't complain when ordering by chat count
    scope = scope.group("\"#{table_name}\".\"id\"").group("locations.id")

    # order by distance
    scope.order(Location.distance_from(user.location))
  end
end
