require 'spec_helper'

describe OutboundCdr do
  include CdrHelpers

  let(:cdr) { create_cdr(:variables => {"direction" => "outbound"}).typed }
  subject { build_cdr(:variables => {"direction" => "outbound"}).typed }

  describe "factory" do
    it "should be valid" do
      subject.should be_valid
    end
  end

  it "should not be valid without an associated incoming cdr" do
    subject.bridge_uuid = "invalid"
    subject.should_not be_valid
  end

  # tests the database uniqueness constraint of phone_calls
  it "should allow multiple records to be saved" do
    cdr
    another_cdr = create_cdr(:variables => {"direction" => "outbound"}).typed
    cdr.phone_call.should be_nil
    another_cdr.phone_call.should be_nil
  end

  describe "callbacks" do
    describe "before validate on create" do
      it "should correctly populate the required attributes" do
        subject.valid?
        subject.bridge_uuid.should == subject.inbound_cdr.uuid
      end
    end
  end
end
