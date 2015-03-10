require 'rails_helper'

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
        expect(report.data).to eq(asserted_report(:empty => true))
      end
    end

    describe ".year" do
      it "should return the report year" do
        expect(report.year).to eq(base_report_data["report"]["year"])
      end
    end

    describe ".month" do
      it "should return the report month" do
        expect(report.month).to eq(base_report_data["report"]["month"])
      end
    end

    describe ".filename" do
      it "should return a filename from the month and the date" do
        expect(report.filename).to eq(asserted_report_filename(:january, 2014))
      end
    end

    describe ".type" do
      it "should return 'application/json'" do
        expect(report.type).to eq(asserted_report_type)
      end
    end

    describe ".data" do
      it "should return the report data" do
        expect(report.data).to eq(asserted_report)
      end
    end

    describe ".generated?" do
      context "given the report has been generated" do
        it "should return true" do
          expect(report).to be_generated
        end
      end

      context "given the report has not been generated (or has been cleared)" do
        before do
          report.clear
        end

        it "should return false" do
          expect(report).not_to be_generated
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
      expect(report.data).to eq(asserted_report(:empty => true))
    end
  end

  describe "#valid?" do
    context "given it has a month and a year" do
      it "should return true" do
        expect(subject).to be_valid
      end
    end

    context "given is does not have a month or a year" do
      it "should return false" do
        expect(Report.new(:year => 2014)).not_to be_valid
      end
    end
  end

  describe "#generate!" do
    include MobilePhoneHelpers
    include TimecopHelpers
    include CdrHelpers

    def increment_sms(service_metadata, options = {})
      service_metadata["headers"] ||= asserted_sms_report_headers

      data = service_metadata["data"] ||= []
      day = data.find { |day_row| day_row[0] == options[:day]}
      day ? day.replace([day[0], day[1] + 1]) : data << [options[:day], 1]

      service_metadata["quantity"] ||= 0
      service_metadata["quantity"] += 1
    end

    def increment_ivr(service_metadata, options = {})
      cdr = options[:cdr]
      service_metadata["headers"] ||= asserted_cdr_report_headers

      data = service_metadata["data"] ||= []
      data_row = asserted_cdr_data_row(cdr)
      data << data_row

      service_metadata["quantity"] ||= 0
      service_metadata["quantity"] += data_row.last
    end

    def increment_charge(service_metadata, options = {})
      charge_request = options[:charge_request]
      service_metadata["headers"] ||= asserted_charge_report_headers

      data = service_metadata["data"] ||= []
      data_row = asserted_charge_request_data_row(charge_request)
      data << data_row

      service_metadata["quantity"] ||= 0
      service_metadata["quantity"] += 1
    end

    def create_sample_interaction(options)
      report_data = options[:report]["report"]
      Timecop.freeze(sometime_in(options)) do
        with_operators do |number_parts, assertions|
          full_number = number_parts.join

          user = User.find_by_mobile_number(full_number) || create(:user, :mobile_number => full_number)

          create(:message, :from => full_number, :user => user)

          cdr = create_cdr(
            :cdr_variables => {
              "variables" => {
                "sip_from_user" => full_number, "billsec" => "60"
              }
            },
            :user => user
          )

          charge_request = create(:charge_request, :successful, :user => user)

          next unless subject.month == options[:month] && options[:year] == options[:year]
          countries_report = report_data["countries"] ||= {}
          country_report = countries_report[assertions["country_id"]] ||= {}
          operators_report = country_report["operators"] ||= {}
          next unless assertions["services"]
          operator_report = operators_report[assertions["id"]] ||= {}
          services_report = operator_report["services"] ||= assertions["services"].dup
          services_report.each do |service, service_metadata|
            service_type = service_metadata["type"]
            send("increment_#{service_type}",
            service_metadata,
            options.merge(:cdr => cdr, :charge_request => charge_request))
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
      expect(report).not_to be_generated
      generated_report = JSON.parse(subject.generate!)
      expect(generated_report).to eq(asserted_report)
      expect(report).to be_generated
    end
  end
end
