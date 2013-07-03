class InboundCdr < CallDataRecord
  validates :rfc2822_date, :presence => true

  before_validation :set_inbound_cdr_attributes, :on => :create

  private

  def set_inbound_cdr_attributes
    if body.present?
      self.rfc2822_date ||= unescaped_variable("RFC2822_DATE")
    end
  end
end
