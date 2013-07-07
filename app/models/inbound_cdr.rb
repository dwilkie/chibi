class InboundCdr < CallDataRecord
  validates :rfc2822_date, :presence => true

  before_validation :set_inbound_cdr_attributes, :on => :create

  private

  def set_inbound_cdr_attributes
    if body.present?
      self.rfc2822_date ||= unescaped_variable("RFC2822_DATE")
    end
  end

  def cdr_from
    valid_source("sip_from_user") || valid_source("sip_P_Asserted_Identity")
  end

  def find_related_phone_call
    PhoneCall.find_by_sid(uuid)
  end
end
