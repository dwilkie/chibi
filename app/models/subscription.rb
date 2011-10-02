class Subscription < ActiveRecord::Base
  belongs_to :user
  belongs_to :account

  has_many :messages
  has_many :replies

  validates :user, :account, :presence => true

end

