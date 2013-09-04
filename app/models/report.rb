class Report
  attr_accessor :month, :year

  def initialize(options)
    self.month = options[:month]
    self.year = options[:year]
  end

  # generates a JSON report for the registered operators for the month and year such as:
  # {
  #   "year" => 2014,
  #   "month" => 1,
  #   "kh" => {
  #     "smart" => {
  #       "daily" => {
  #         "messages" => {1 => 1023, 2 => 1345, ..., 31 => 1234},
  #         "ivr" => {
  #           "duration" => {1 => 234, 2 => 321, ..., 31 => 422},
  #           "bill_sec" => {1 => 232, 2 => 319, ..., 31 => 421,
  #           }
  #         }
  #       }
  #     },
  #     "beeline" => {
  #       "daily" => {
  #         "messages" => {1 => 1023, 2 => 1345, ..., 31 => 1234}
  #       }
  #     },
  #  "th" => ...

  def generate!
    report = {}
    Torasup::Operator.registered.each do |country_id, operators|
      country_report = report[country_id] ||= {}
      operators.each do |operator_id, operator_metadata|
        operator_report = country_report[operator_id] ||= {}
        daily_report = operator_report["daily"] ||= {}
        operator_options = {:operator => operator_id, :country_code => country_id}
        generate_messages_report!(daily_report, operator_options)
        generate_ivr_report!(daily_report, operator_options) if operator_metadata["dial_string"]
      end
    end
    report
  end

  private

  def generate_messages_report!(daily_report, operator_options)
    daily_report["messages"] ||= Message.overview_of_created(report_options(operator_options))
  end

  def generate_ivr_report!(daily_report, operator_options)
    ivr_report = daily_report["ivr"] ||= {}
    ivr_report["duration"] ||= InboundCdr.overview_of_duration(
      :duration, report_options(operator_options)
    )
    ivr_report["bill_sec"] ||= InboundCdr.overview_of_duration(
      :bill_sec, report_options(operator_options)
    )
  end

  def report_options(options = {})
    {
      :format => :report, :between => time_of_month.beginning_of_month..time_of_month.end_of_month
    }.merge(options)
  end

  def time_of_month
    @time_of_month ||= Time.new(year, month)
  end
end
