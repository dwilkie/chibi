class Chat < ActiveRecord::Base
  belongs_to :user
  belongs_to :friend, :class_name => 'User'

  has_many :active_users, :class_name => 'User', :foreign_key => "active_chat_id"
  has_many :replies

  validates :user, :friend, :presence => true
end

