class Message < ActiveRecord::Base
  belongs_to :subscription
  has_one :reply

  attr_accessible :from, :body

  def origin
    from
  end

  def process!
    MessageHandler.new.process! self
  end
end

