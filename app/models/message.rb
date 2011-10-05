class Message < ActiveRecord::Base
  belongs_to :user
  belongs_to :chat

  attr_accessible :from, :body

  def origin
    from
  end

  def process!
    MessageHandler.new.process! self
  end
end

