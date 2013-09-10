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

  def generate!
    report_data = {"month" => month, "year" => year}
    countries_report = report_data["countries"] ||= {}
    Torasup::Operator.registered.each do |country_id, operators|
      country_report = countries_report[country_id] ||= {}
      operators_report = country_report["operators"] ||= {}
      operators.each do |operator_id, operator_metadata|
        operator_report = operators_report[operator_id] ||= {}
        operator_report["billing"] = operator_metadata["billing"].dup
        operator_report["payment_instructions"] = operator_metadata["payment_instructions"].dup
        services_report = operator_report["services"] = operator_metadata["services"].dup
        operator_options = {:operator => operator_id, :country_code => country_id}
        generate_sms_report!(services_report["sms"], operator_options)
        generate_ivr_report!(services_report["ivr"], operator_options) if services_report["ivr"]
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

  def generate_sms_report!(sms_report, operator_options)
    with_interaction_report(sms_report) do |interaction_report, timeframe|
      interaction_report["count"] = Message.overview_of_created(
        report_options(operator_options.merge(:timeframe => timeframe))
      )
    end
    set_quantity(sms_report, "count")
  end

  def generate_ivr_report!(ivr_report, operator_options)
    with_interaction_report(ivr_report) do |interaction_report, timeframe|
      ["duration", "bill_sec"].each do |ivr_report_type|
        interaction_report[ivr_report_type] = InboundCdr.overview_of_duration(
          ivr_report_type, report_options(operator_options.merge(:timeframe => timeframe))
        )
      end
    end
    set_quantity(ivr_report, "duration")
  end

  def with_interaction_report(service_report)
    [:day, :month].each do |timeframe|
      yield(service_report["by_#{timeframe}"] ||= {}, timeframe)
    end
  end

  def report_options(options = {})
    time_of_month = Time.new(year, month)
    {
      :format => :report, :between => time_of_month.beginning_of_month..time_of_month.end_of_month
    }.merge(options)
  end

  def set_quantity(service_report, by_month_field)
    service_report["quantity"] = service_report["by_month"][by_month_field].values.first
  end
end
