class AtMessage < ActiveRecord::Base
  belongs_to :subscription
  attr_accessible :from, :body

  def origin
    from
  end

  def process!
    MessageHandler.new.process! self
  end
end

