require 'spec_helper'

describe InboundCdr do
  include CdrHelpers
  include AnalyzableExamples

  let(:cdr) { create_cdr }
  subject { build_cdr }

  it_should_behave_like "analyzable" do
    let(:group_by_column) { :created_at }
    let(:excluded_resource) { nil }

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
        Timecop.freeze(Time.now) do
          subject.valid?
          subject.rfc2822_date.to_i.should == Time.now.to_i
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
    let(:cdrs) {[]}

    before do
      Timecop.freeze(Time.now)
      cdrs << cdr
      2.times do
        new_cdr = create_cdr(
          :cdr_variables => {"variables" => {"duration" => "60", "billsec" => "59"}}
        )
        new_cdr.update_attribute(:created_at, 8.days.ago)
        cdrs << new_cdr
      end
    end

    after do
      Timecop.return
    end

    describe ".overview_of_duration(duration_column, options = {})" do
      context "passing :duration" do
        it "should return the sum of duration in mins" do
          overview = InboundCdr.overview_of_duration(:duration)
          overview.should include([miliseconds_since_epoch(eight_days_ago), 4])
        end
      end

      context "passing :bill_sec" do
        it "should return the sum of bill_sec in mins" do
          overview = InboundCdr.overview_of_duration(:bill_sec)
          overview.should include([miliseconds_since_epoch(eight_days_ago), 2])
        end
      end

      context "passing :format => :report" do
        it "should return a hash" do
          overview = InboundCdr.overview_of_duration(:duration, :format => :report)
          overview.should be_a(Hash)
        end
      end
    end

    describe ".cdr_report(options = {})" do
      def asserted_cdr(index)
        [cdrs[index].from, cdrs[index].rfc2822_date, cdrs[index].duration, cdrs[index].bill_sec]
      end

      it "should return only the relevant cdr columns" do
        InboundCdr.cdr_report.each_with_index do |reported_cdr, index|
          reported_cdr.should == asserted_cdr(index)
        end
      end

      context "passing :operator => '<operator>', :country_code => '<country_code>'" do
        it "should filter by the operator" do
          InboundCdr.cdr_report(:operator => :foo, :country_code => :kh).should be_empty
        end
      end

      context "passing :between => 7.days.ago..Time.now" do
        it "should filter by the given timeline" do
          InboundCdr.cdr_report(:between => 7.days.ago..Time.now).should == [asserted_cdr(0)]
        end
      end
    end
  end
end
