class Report
  REDIS_KEY = "report"

  attr_accessor :month, :year

  def initialize(options = {})
    self.month = options["month"]
    self.year = options["year"]
    self.class.clear
  end

  def self.clear
    REDIS.del(REDIS_KEY)
  end

  def self.data
    REDIS.get(REDIS_KEY) || "{}"
  end

  def self.month
    parsed_data["month"]
  end

  def self.year
    parsed_data["year"]
  end

  def self.filename
    "chibi_report_" + Time.new(year, month).strftime("%B_%Y").downcase + ".json"
  end

  def self.type
    "application/json"
  end

  def self.generated?
    parsed_data.any?
  end

  def valid?
    month && year
  end

  # generates a JSON report for the registered operators for the month and year such as:
  # {
  #   "report" => {
  #     "year" => 2014,
  #     "month" => 1,
  #     "countries" => {
  #       "kh" => {
  #         "operators" => {
  #           "smart" => {
  #             "daily" => {
  #               "messages" => {1 => 1023, 2 => 1345, ..., 31 => 1234},
  #               "ivr" => {
  #                 "duration" => {1 => 234, 2 => 321, ..., 31 => 422},
  #                 "bill_sec" => {1 => 232, 2 => 319, ..., 31 => 421}
  #               }
  #             }
  #           },
  #           "beeline" => {
  #             "daily" => {
  #               "messages" => {1 => 1023, 2 => 1345, ..., 31 => 1234}
  #             }
  #           }
  #         }
  #       },
  #       "th" => {
  #         ...
  #       }
  #     }
  #   }
  # }

  def generate!
    report_data = {"month" => month, "year" => year}
    countries_report = report_data["countries"] ||= {}
    Torasup::Operator.registered.each do |country_id, operators|
      country_report = countries_report[country_id] ||= {}
      operators_report = country_report["operators"] ||= {}
      operators.each do |operator_id, operator_metadata|
        operator_report = operators_report[operator_id] ||= {}
        daily_report = operator_report["daily"] ||= {}
        operator_options = {:operator => operator_id, :country_code => country_id}
        generate_messages_report!(daily_report, operator_options)
        generate_ivr_report!(daily_report, operator_options) if operator_metadata["dial_string"]
      end
    end
    store_report("report" => report_data)
    self.class.data
  end

  private

  def self.parsed_data
    JSON.parse(data)["report"] || {}
  end

  def store_report(value)
    REDIS.set(REDIS_KEY, value.to_json)
  end

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
    time_of_month = Time.new(year, month)
    {
      :format => :report, :between => time_of_month.beginning_of_month..time_of_month.end_of_month
    }.merge(options)
  end
end
