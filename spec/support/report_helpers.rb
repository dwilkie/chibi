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
end
