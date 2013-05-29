class InboundCdr < CallDataRecord
  validates :phone_call, :rfc2822_date, :presence => true
  validates :phone_call_id, :uniqueness => true

  before_validation(:on => :create) do
    set_inbound_cdr_attributes
  end

  private

  def set_inbound_cdr_attributes
    if body.present?
      self.rfc2822_date ||= Rack::Utils.unescape(variables["RFC2822_DATE"])
      self.phone_call ||= PhoneCall.find_by_sid(uuid)
    end
  end
end
