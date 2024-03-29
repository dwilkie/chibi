class Report
  REDIS_KEY = "report"

  attr_accessor :month, :year

  def initialize(options = nil)
    options ||= {}
    self.month = options["month"]
    self.year = options["year"]
  end

  def valid?
    @month && @year
  end

  def month
    @month || parsed_data["month"]
  end

  def year
    @year || parsed_data["year"]
  end

  def generate!
    report_data = {"month" => month, "year" => year}
    countries_report = report_data["countries"] ||= {}
    Torasup::Operator.registered.each do |country_id, operators|
      country_report = countries_report[country_id] ||= {}
      operators_report = country_report["operators"] ||= {}
      operators.each do |operator_id, operator_metadata|
        next unless operator_metadata["services"]
        operator_report = operators_report[operator_id] ||= {}
        services_report = operator_report["services"] = operator_metadata["services"].dup
        operator_options = {:operator => operator_id, :country_code => country_id}
        operator_report["services"].each do |service, service_metadata|
          service_type = service_metadata["type"]
          send("generate_#{service_type}_report!", service_metadata, operator_options)
        end
      end
    end
    store_report("report" => report_data)
    data
  end

  def clear
    redis.del(REDIS_KEY)
  end

  def store_report(value)
    redis.set(REDIS_KEY, value.to_json)
  end

  def data
    redis.get(REDIS_KEY) || "{}"
  end

  def filename
    "chibi_report_" + Time.zone.local(year, month).strftime("%B_%Y").downcase + ".json"
  end

  def type
    "application/json"
  end

  def generated?
    parsed_data.any?
  end

  private

  def parsed_data
    JSON.parse(data)["report"] || {}
  end

  def redis
    @redis ||= Redis.new(redis_options)
  end

  def redis_options
    {:host => redis_uri.host, :port => redis_uri.port, :password => redis_uri.password}
  end

  def redis_uri
    @redis_uri ||= URI.parse(redis_url)
  end

  def redis_url
    ENV[redis_provider].to_s
  end

  def redis_provider
    ENV["REDIS_PROVIDER"].to_s
  end

  def generate_sms_report!(service_metadata, operator_options)
    daily_data = Message.overview_of_created(
      report_options(operator_options.merge(:timeframe => :day))
    ).to_a

    service_metadata["quantity"] = daily_data.inject(0) { |sum, daily_total| sum + daily_total.last }
    service_metadata["headers"] = ["day", "total_mo"]
    service_metadata["data"] = daily_data
  end

  def generate_ivr_report!(service_metadata, operator_options)
    cdr_report = InboundCdr.cdr_report(report_options(operator_options))

    service_metadata["quantity"] = cdr_report.inject(0) { |sum, cdr_detail| sum + cdr_detail.last }
    service_metadata["headers"] = InboundCdr.cdr_report_columns(:header => true)
    service_metadata["data"] = cdr_report
  end

  def generate_charge_report!(service_metadata, operator_options)
    charge_report = ChargeRequest.charge_report(report_options(operator_options))

    service_metadata["quantity"] = charge_report.count
    service_metadata["headers"] = ChargeRequest.charge_report_columns(:header => true)
    service_metadata["data"] = charge_report
  end

  def report_options(options = {})
    time_of_month = Time.zone.local(year, month)
    {
      :timeframe_format => :report, :between => time_of_month.beginning_of_month..time_of_month.end_of_month
    }.merge(options)
  end
end
