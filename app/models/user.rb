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
  validates :username, :uniqueness => true

  before_validation(:on => :update) do
    self.username = name.gsub(/\s+/, "") << id.to_s if attribute_present?(:name) && persisted?
  end

  PROFILE_ATTRIBUTES = ["name", "date_of_birth", "location", "gender", "looking_for"]

  # disables sunspots autotomatic autoindexing...
  # turn this back on when solr is enabled on Heroku
  searchable :auto_index => false do
    string  :gender
    string  :looking_for
    text    :location, :boost => 5
    integer :active_chat_id, :references => Chat

    integer :friend_ids, :multiple => true do
      chats.map(&:friend_id)
    end

    integer :chat_friend_ids, :multiple => true do
      participating_chats.map(&:user_id)
    end

    date :date_of_birth
    # http://stackoverflow.com/questions/5103077/date-range-facets-with-sunspot-in-ruby-on-rails
  end

  def self.match(user)
    search = self.search do
      # Match the gender i'm looking for if I actually care
      with(:gender, user.looking_for) if user.looking_for
      any_of do
        with(:looking_for, user.gender) # Match people looking for my gender
        with(:looking_for, nil)      # or are indifferent
      end

      # store the co-ordinates and do a solar spatial search here
      fulltext user.location do
        fields :location
        # for some reason minimum_match 0 still requires at least one match
        minimum_match 0
      end

      # do a fulltext search on interests with a minimum match of 0
      # boosting up chatty users

      # don't match anyone that the user already chatted with
      # (don't match anyone who has a chat friend with the user's id)
      without(:chat_friend_ids, user.id)

      # don't match anyone that already chatted with the user
      # (don't match anyone who has a friend with the user's id)
      without(:friend_ids, user.id)

      # don't match anyone that is currently in a chat
      with(:active_chat_id, nil)

      # Use facets here to split out the desired date ranges
      # then return the results based off their sizes

#      Event.search do
#        facet :start_time do
#          bod = Time.zone.now.beginning_of_day
#          row :today do
#            with :start_time, bod..(bod + 1)
#          end
#          row :tomorrow do
#            with :start_time, (bod + 1)..(bod + 2)
#          end
#          # etc.
#        end
#      end

      without(user) # don't include the user in the search results

      # limit to only 5 matches
      paginate(:page => 1, :per_page => 5)
    end
    search.results.first
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

