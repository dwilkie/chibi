module ReportHelpers
  private

  def sample_report_data
    @sample_report_data ||= {"report" => {"month" => 1, "year" => 2014}}
  end

  def build_report
    Report.new(sample_report_data["report"])
  end

  def store_report
    build_report.store_report(sample_report_data)
  end

  def mock_redis
    @mock_redis ||= MockRedis.new
  end

  def stub_redis
    allow(Redis).to receive(:new).and_return(mock_redis)
  end

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
