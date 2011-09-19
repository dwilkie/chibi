class Account < ActiveRecord::Base
  has_many :subscriptions
  has_many :users, :through => :subscriptions

  has_secure_password

  validates :username, :email, :presence => true, :uniqueness => true
  validates :password, :presence => true, :on => :create
end

