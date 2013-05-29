class OutboundCdr < CallDataRecord
  validates :bridge_uuid, :inbound_cdr_id, :presence => true

  before_validation(:on => :create) do
    set_outbound_cdr_attributes
  end

  private

  def set_outbound_cdr_attributes
    if body.present?
      self.bridge_uuid ||= variables["bridge_uuid"]
      self.inbound_cdr = InboundCdr.where(:direction => "inbound").find_by_uuid(bridge_uuid)
    end
  end
end
