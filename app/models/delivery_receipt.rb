class DeliveryReceipt < ActiveRecord::Base
  belongs_to :reply
  validates :reply, :token, :state, :presence => true
  validates :token, :uniqueness => {:scope => :state}

  before_validation :link_to_reply

  private

  def link_to_reply
    self.reply = Reply.find_by_token(token)
  end
end
