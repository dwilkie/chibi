require 'spec_helper'

describe InboundCdr do
  include CdrHelpers

  let(:cdr) { create_cdr }
  subject { build_cdr }

  describe "factory" do
    it "should be valid" do
      subject.should be_valid
    end
  end

  it "should not be valid without a rfc2822 date" do
    cdr.rfc2822_date = nil
    cdr.should_not be_valid
  end

  it "should not be valid without a related user" do
    build_cdr(
      :variables => {
        "sip_from_user" => "invalid", "sip_P-Asserted-Identity" => "invalid"
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
end
