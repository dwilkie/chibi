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

    # don't match users who already initiated a chat with this user
    match_scope = match_scope.joins("LEFT OUTER JOIN chats AS initiated_chats ON initiated_chats.user_id = users.id").where("\"initiated_chats\".\"friend_id\" != ? OR \"initiated_chats\".\"friend_id\" IS NULL", user.id)

    # don't match users who this user has already initiated a chat with
    match_scope = match_scope.joins("LEFT OUTER JOIN chats as responded_chats ON responded_chats.friend_id = users.id").where("\"responded_chats\".\"user_id\" != ? OR \"responded_chats\".\"user_id\" IS NULL", user.id)

    # only match users from the same country
    match_scope = match_scope.joins(:location).where(:locations => {:country_code => user.location.country_code})

    # order by distance
    match_scope = match_scope.order(Location.distance_from(user.location))

    # then age difference
    match_scope = match_scope.order("ABS(DATE('#{user.date_of_birth}') - #{table_name}.date_of_birth)") if user.date_of_birth?

    match_scope
  end

  def female?
    gender == 'f'
  end

  def male?
    gender == 'm'
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
    self.date_of_birth = value.years.ago.utc
  end

  def currently_chatting?
    active_chat_id?
  end
end
