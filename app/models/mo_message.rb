class MoMessage < ActiveRecord::Base
  belongs_to :user

  attr_accessible :from, :body, :guid
  after_create :process!

  def origin
    Nuntium.address(from)
  end

  def process!
    MessageHandler.new.process! self
  end
end

