class OutboundCdr < CallDataRecord
  validates :bridge_uuid, :inbound_cdr_id, :presence => true

  before_validation(:on => :create) do
    set_outbound_cdr_attributes
  end

  after_create :activate_chat

  private

  def set_outbound_cdr_attributes
    if body.present?
      self.bridge_uuid ||= variables["bridge_uuid"]
      self.inbound_cdr = InboundCdr.where(:direction => "inbound").find_by_uuid(bridge_uuid)
    end
  end

  def activate_chat
    Chat.find_by_user_id_and_friend_id(inbound_cdr.user_id, user.id).try(:reactivate!, :force => true)
  end
end
