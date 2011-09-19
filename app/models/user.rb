class User < ActiveRecord::Base
  has_many :subscriptions
  has_many :accounts, :through => :subscriptions

  # describes initiated friendships i.e. chat initiated by user
  has_many :friendships
  has_many :friends, :through => :friendships

  # decribes accepted friendships i.e. chat initiated by accepted friend
  has_many :accepted_friendships, :class_name => "Friendship", :foreign_key => "friend_id"
  has_many :accepted_friends, :through => :accepted_friendships, :source => :user

  has_many :user_matches
  has_many :friend_suggestions, :through => :user_matches

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
    string :sex
    string :looking_for
    text :location, :boost => 5
    integer :friend_ids, :multiple => true do
      friends.map(&:id)
    end

    integer :accepted_friend_ids, :multiple => true do
      accepted_friends.map(&:id)
    end
    date :date_of_birth
    # http://stackoverflow.com/questions/5103077/date-range-facets-with-sunspot-in-ruby-on-rails
  end

  def self.matches(user, limit = 5)
    search = self.search do
      # Match the sex i'm looking for if I actually care
      with(:sex, user.looking_for) if user.looking_for
      any_of do
        with(:looking_for, user.sex) # Match people looking for my sex
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

      # exclude users who are already friends

      # exclude users who have already accepted me as a friend
      without(:accepted_friend_ids, user.id)

      # exclude users who I have accepted as a friend
      without(:friend_ids, user.id)

      #without(:accepted_friend_ids).any_of(user.accepted_friends.map(&:id))
      # exclude users who have already been searched for by this user (they already have the results)

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
    search
  end
end

