require_relative 'redis'

module ReportHelpers
  include RedisHelpers

  private

  def asserted_report_type
    'application/json'
  end

  def asserted_report_filename(month, year)
    "chibi_report_#{month}_#{year}.json"
  end

  def asserted_cdr_report_headers
    ["id", "number", "timestamp", "duration", "rounded_mins"]
  end

  def asserted_cdr_data_row(cdr)
    [cdr.id, cdr.from, cdr.rfc2822_date, cdr.bill_sec, (cdr.bill_sec / 60) + 1]
  end

  def asserted_charge_report_headers
    ["transaction_id", "number", "timestamp", "result"]
  end

  def asserted_charge_request_data_row(cr)
    [cr.id, cr.user.mobile_number, cr.created_at, cr.state]
  end

  def asserted_sms_report_headers
    ["day", "total_mo"]
  end
end
