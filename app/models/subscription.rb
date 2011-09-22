class Subscription < ActiveRecord::Base
  belongs_to :user
  belongs_to :account

  has_many :at_messages
  has_many :ao_messages

  validates :user, :account, :presence => true

end

