require 'spec_helper'

describe InboundCdr do
  include CdrHelpers
  include AnalyzableExamples
  include ReportHelpers

  let(:cdr) { create_cdr }
  subject { build_cdr }

  it_should_behave_like "analyzable" do
    let(:group_by_column) { :created_at }

    def create_resource(*args)
      create_cdr(*args)
    end
  end

  describe "factory" do
    it "should be valid" do
      subject.should be_valid
    end
  end

  describe "associations" do
    describe "#outbound_cdrs" do
      it "should have_many" do
        subject.outbound_cdrs.should be_empty
      end
    end
  end

  it "should not be valid without a rfc2822 date" do
    cdr.rfc2822_date = nil
    cdr.should_not be_valid
  end

  it "should not be valid without a related user" do
    build_cdr(
      :cdr_variables => {
        "variables" => {"sip_from_user" => "invalid"}
      }
    ).should_not be_valid
  end

  it_should_behave_like "communicable from user" do
    let(:communicable_resource) { cdr }
  end

  describe "callbacks" do
    describe "before_validation(:on => :create)" do
      it "should populate the required attributes" do
        Timecop.freeze(Time.current) do
          subject.valid?
          subject.rfc2822_date.to_i.should == Time.current.to_i
          subject.phone_call.should be_nil
        end
      end

      context "given there's a related phone call" do
        let(:phone_call) { create(:phone_call) }
        subject { build_cdr(:phone_call => phone_call) }

        it "should set the related phone call" do
          subject.valid?
          subject.phone_call.should == phone_call
        end
      end
    end
  end

  describe "reporting" do
    def create_cdr(options = {})
      return super if options.delete(:standard)
      super(
        :cdr_variables => {
          "variables" => {
            "duration" => "60",
            "billsec" => options[:billsec] || "59",
            "RFC2822_DATE" => Rack::Utils.escape((options[:rfc2822_date] || (8.days.ago - 1.second)).rfc2822)
          }
        }
      )
    end

    let(:cdrs) { [cdr_1, cdr_2, cdr_3, cdr_4] }

    let(:cdr_1) { create_cdr(:standard => true) }
    let(:cdr_2) { create_cdr }
    let(:cdr_3) { create_cdr }
    let(:cdr_4) { create_cdr(:billsec => "0") }

    before do
      Timecop.freeze(Time.current) { cdrs }
    end

    describe ".overview_of_duration(options = {})" do
      it "should return the sum of bill_sec in mins" do
        overview = InboundCdr.overview_of_duration
        overview.should include([miliseconds_since_epoch(eight_days_ago), 2])
      end
    end

    describe ".cdr_report_columns(:header => true)" do
      it "should return the column headers for the cdr report" do
        InboundCdr.cdr_report_columns(:header => true).should == asserted_cdr_report_headers
      end
    end

    describe ".cdr_report(options = {})" do
      def run_filter(options = {})
        InboundCdr.cdr_report(options)
      end

      it "should return only the relevant cdr columns" do
        results = run_filter
        results[0].should == asserted_cdr_data_row(cdr_2)
        results[1].should == asserted_cdr_data_row(cdr_3)
        results[2].should == asserted_cdr_data_row(cdr_1)
        results.should_not include(asserted_cdr_data_row(cdr_4))
      end

      it_should_behave_like "filtering by operator"

      it_should_behave_like "filtering by time" do
        let(:time_period) { 8.days.ago..Time.current }
        let(:filtered_by_time_results) { [asserted_cdr_data_row(cdr_1)] }
      end
    end
  end
end
