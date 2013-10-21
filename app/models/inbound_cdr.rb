class InboundCdr < CallDataRecord
  validates :rfc2822_date, :presence => true

  before_validation :set_inbound_cdr_attributes, :on => :create

  has_many :outbound_cdrs

  include Chibi::Analyzable

  def self.overview_of_duration(duration_column, options = {})
    result = group_by_timeframe(options).sum("(#{duration_column} / 60) + 1").integerify!
    options[:format] == :report ? result : result.to_a
  end

  def self.cdr_report(options = {})
    by_operator(options).between_dates(options).order(:rfc2822_date, :id).pluck(:from, :rfc2822_date, :duration, :bill_sec)
  end

  private

  def set_inbound_cdr_attributes
    if body.present?
      self.rfc2822_date ||= unescaped_variable("RFC2822_DATE")
    end
  end

  def cdr_from
    valid_source("sip_from_user_stripped") || valid_source("sip_from_user") || valid_source("sip_P_Asserted_Identity")
  end

  def find_related_phone_call
    PhoneCall.find_by_sid(uuid)
  end
end
