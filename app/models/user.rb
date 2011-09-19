class User < ActiveRecord::Base
  has_many :subscriptions
  has_many :accounts, :through => :subscriptions

  # describes initiated friendships i.e. chat initiated by user
  has_many :friendships
  has_many :friends, :through => :friendships

  # decribes accepted friendships i.e. chat initiated by accepted friend
  has_many :accepted_friendships, :class_name => "Friendship", :foreign_key => "friend_id"
  has_many :accepted_friends, :through => :accepted_friendships, :source => :user

  # describes friendship suggestions given to a user
  has_many :friendship_suggestions
  has_many :friend_suggestions, :through => :friendship_suggestions, :source => :suggested_friend

  # describes friendship suggestions given to a user from the point of view of the suggested user
  has_many :potential_friendships, :class_name => "FriendshipSuggestion", :foreign_key => "suggested_friend_id"
  has_many :potential_friends, :through => :potential_friendships, :source => :user

  validates :mobile_number, :presence => true, :uniqueness => true
  validates :username, :uniqueness => true

  before_validation(:on => :update) do
    self.username = name.gsub(/\s+/, "") << id.to_s if attribute_present?(:name) && persisted?
  end

  state_machine :initial => :newbie do
    event :register_details do
      transition [:newbie] => :registered_details
    end

    event :register_interests do
      transition [:registered_details] => :registered_interests
    end

    event :register_looking_for do
      transition [:registered_interests] => :ready
    end
  end

  searchable do
    string :gender
    string :looking_for
    text :location, :boost => 5

    integer :friend_ids, :multiple => true do
      friendships.map(&:friend_id)
    end

    integer :accepted_friend_ids, :multiple => true do
      accepted_friendships.map(&:user_id)
    end

    integer :potential_friend_ids, :multiple => true do
      potential_friendships.map(&:user_id)
    end

    date :date_of_birth
    # http://stackoverflow.com/questions/5103077/date-range-facets-with-sunspot-in-ruby-on-rails
  end

  def self.matches(user, limit = 5)
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

      # don't match anyone that the user already befriended
      # (don't match anyone who has an accepted friend with the user's id)
      without(:accepted_friend_ids, user.id)

      # don't match anyone that already befriended the user
      # (don't match anyone who has a friend with the user's id)
      without(:friend_ids, user.id)

      # don't match anyone who has already been suggested to this user before
      # (don't match anyone who has a potential friendship with the user's id)
      without(:potential_friend_ids, user.id)

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
    end
    search.results
  end
end

