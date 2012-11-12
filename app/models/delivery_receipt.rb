class DeliveryReceipt < ActiveRecord::Base
  belongs_to :message
  validates :message, :guid, :state, :presence => true
  validates :guid, :uniqueness => {:scope => :state}

  before_validation :link_to_message

  private

  def link_to_message
    self.message = Message.find_by_guid(guid)
  end
end
