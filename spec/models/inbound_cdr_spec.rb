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
        "variables" => {
          "sip_from_user" => "invalid", "sip_P-Asserted-Identity" => "invalid"
        }
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

  describe ".overview_of_duration(duration_column, options = {})" do
    before do
      Timecop.freeze(Time.now)
      cdr
      2.times do
        create_cdr(
          :cdr_variables => {"variables" => {"duration" => "60", "billsec" => "59"}}
        ).update_attribute(:created_at, 8.days.ago)
      end
    end

    after do
      Timecop.return
    end

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
end
