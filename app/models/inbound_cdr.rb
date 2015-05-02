class InboundCdr < CallDataRecord
  validates :rfc2822_date, :presence => true

  before_validation :set_inbound_cdr_attributes, :on => :create

  has_many :outbound_cdrs

  include Chibi::Analyzable

  def self.overview_of_duration(options = {})
    group_by_timeframe(options.merge(:group_by_column => default_date_column)).billable.sum(rounded_mins_sql).integerify.to_a
  end

  def self.cdr_report(options = {})
    by_operator(options).between_dates(
      {:date_column => default_date_column}.merge(options)
    ).billable.order(default_date_column, :id).pluck(*cdr_report_columns)
  end

  def self.cdr_report_columns(options = {})
    columns = {
      "id" => :id,
      "number" => :from,
      "timestamp" => default_date_column,
      "duration" => :bill_sec,
      "rounded_mins" => rounded_mins_sql
    }
    options[:header] ? columns.keys : columns.values
  end

  private

  def self.billable
    where("bill_sec > ?", 0)
  end

  def self.rounded_mins_sql
    "(bill_sec / 60) + 1"
  end

  def self.default_date_column
    :rfc2822_date
  end

  def set_inbound_cdr_attributes
    if body.present?
      self.rfc2822_date ||= Time.at(unescaped_variable("start_epoch").to_i)
    end
  end

  def cdr_from
    valid_source("sip_from_user_stripped") || valid_source("sip_from_user") || valid_source("sip_P_Asserted_Identity")
  end

  def find_related_phone_call
    PhoneCall.find_by_sid(uuid)
  end
end
