class Message < ActiveRecord::Base
  belongs_to :user
  belongs_to :chat, :touch => true

  validates :user, :presence => true
  validates :from, :presence => true

  attr_accessible :from, :body

  alias_attribute :origin, :from

  def body
    read_attribute(:body).to_s
  end

  def process!
    MessageHandler.new.process! self
  end
end
