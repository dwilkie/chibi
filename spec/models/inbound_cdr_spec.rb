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

  describe "callbacks" do
    describe "before validate on create" do
      it "should correctly populate the required attributes" do
        Timecop.freeze(Time.now) do
          subject.valid?
          subject.uuid.should == subject.phone_call.sid
          subject.rfc2822_date.to_i.should == Time.now.to_i
        end
      end
    end
  end
end
