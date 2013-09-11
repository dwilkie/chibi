require 'spec_helper'

describe Report do
  include ReportHelpers

  let(:base_report_data) do
    {
      "report" => {"month" => 1, "year" => 2014}
    }
  end

  subject { Report.new(base_report_data["report"]) }

  def set_report
    REDIS.set("report", base_report_data.to_json)
  end

  def asserted_report(options = {})
    return "{}" if options[:empty]
    base_report_data.to_json
  end

  def report
    subject.class
  end

  before do
    stub_redis
  end

  describe "singleton methods" do
    before do
      report
      set_report
    end

    describe ".clear" do
      it "should clear the report" do
        report.clear
        report.data.should == asserted_report(:empty => true)
      end
    end

    describe ".year" do
      it "should return the report year" do
        report.year.should == base_report_data["report"]["year"]
      end
    end

    describe ".month" do
      it "should return the report month" do
        report.month.should == base_report_data["report"]["month"]
      end
    end

    describe ".filename" do
      it "should return a filename from the month and the date" do
        report.filename.should == asserted_report_filename(:january, 2014)
      end
    end

    describe ".type" do
      it "should return 'application/json'" do
        report.type.should == asserted_report_type
      end
    end

    describe ".data" do
      it "should return the report data" do
        report.data.should == asserted_report
      end
    end

    describe ".generated?" do
      context "given the report has been generated" do
        it "should return true" do
          report.should be_generated
        end
      end

      context "given the report has not been generated (or has been cleared)" do
        before do
          report.clear
        end

        it "should return false" do
          report.should_not be_generated
        end
      end
    end
  end

  describe "#initialize(options = {})" do
    before do
      set_report
    end

    it "should clear the report" do
      subject
      report.data.should == asserted_report(:empty => true)
    end
  end

  describe "#valid?" do
    context "given it has a month and a year" do
      it "should return true" do
        subject.should be_valid
      end
    end

    context "given is does not have a month or a year" do
      it "should return false" do
        Report.new(:year => 2014).should_not be_valid
      end
    end
  end

  describe "#generate!" do
    include MobilePhoneHelpers
    include TimecopHelpers
    include CdrHelpers

    def increment_interactions(service_report, key, options = {})
      options[:by] ||= 1
      [:day, :month].each do |period|
        interaction_report = service_report["by_#{period}"] ||= {}
        interaction_report = interaction_report[key] ||= {}
        interaction_report[options[period]] ||= 0
        interaction_report[options[period]] += options[:by]
        if options[:increment_quantity] && period == :month
          service_report["quantity"] = service_report["by_month"][key].values.first
        end
      end
    end

    def create_sample_interaction(options)
      report_data = options[:report]["report"]
      Timecop.freeze(sometime_in(options)) do
        with_operators do |number_parts, assertions|
          full_number = number_parts.join

          create(:message, :from => full_number)
          cdr = create_cdr(
            :cdr_variables => {
              "variables" => {
                "sip_from_user" => full_number, "duration" => "60", "billsec" => "59"
              }
            }
          )

          next unless subject.month == options[:month] && options[:year] == options[:year]
          countries_report = report_data["countries"] ||= {}
          country_report = countries_report[assertions["country_id"]] ||= {}
          operators_report = country_report["operators"] ||= {}
          operator_report = operators_report[assertions["id"]] ||= {}
          operator_report["billing"] ||= assertions["billing"].dup
          operator_report["payment_instructions"] ||= assertions["payment_instructions"].dup
          services_report = operator_report["services"] ||= assertions["services"].dup
          increment_interactions(
            services_report["sms"], "count", options.merge(:increment_quantity => true)
          )
          if ivr_report = services_report["ivr"]
            increment_interactions(
              ivr_report, "duration", options.merge(:by => 2, :increment_quantity => true)
            )
            increment_interactions(ivr_report, "bill_sec", options)
            cdr_report = ivr_report["cdr"] ||= []
            cdr_report << [cdr.from, cdr.rfc2822_date, cdr.duration, cdr.bill_sec]
          end
        end
      end
    end

    let(:asserted_report) do
      report = base_report_data
      interaction_options = {:report => report, :day => 1, :month => 1, :year => 2014}
      create_sample_interaction(interaction_options)
      create_sample_interaction(interaction_options.merge(:day => 31))
      create_sample_interaction(interaction_options.merge(:day => 15, :month => 12, :year => 2013))
      JSON.parse(report.to_json)
    end

    it "should generate a report" do
      asserted_report
      report.should_not be_generated
      JSON.parse(subject.generate!).should == asserted_report
      report.should be_generated
    end
  end
end
