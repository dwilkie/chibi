class InboundCdr < CallDataRecord
  validates :rfc2822_date, :presence => true

  before_validation :set_inbound_cdr_attributes, :on => :create

  has_many :outbound_cdrs

  include Chibi::Analyzable

  def self.overview_of_duration(options = {})
    highcharts_array(group_by_timeframe(options).sum("(duration / 60) + 1"))
  end

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
