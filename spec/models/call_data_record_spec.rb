require 'spec_helper'

describe CallDataRecord do
  include CdrHelpers

  let(:cdr) { create_cdr }
  let(:new_cdr) { build_cdr }

  describe "factory" do
    it "should be valid" do
      cdr.should be_valid
    end
  end

  it "should not be valid without a body" do
    cdr.body = nil
    cdr.should_not be_valid
  end

  it "should not be valid without a direction" do
    cdr.direction = nil
    cdr.should_not be_valid
  end

  it "should not be valid without a type" do
    cdr.type = nil
    cdr.should_not be_valid
  end

  it "should not be valid with the wrong type" do
    cdr.type = "Foo"
    cdr.should_not be_valid
  end

  it "should not be valid without a uuid" do
    cdr.uuid = nil
    cdr.should_not be_valid
  end

  it "should not be valid with a duplicate uuid" do
    new_cdr.uuid = cdr.uuid
    new_cdr.should_not be_valid
  end

  it "should be valid without an associated phone call" do
    new_cdr = build_cdr(:cdr_variables => {"variables" => {"uuid" => "invalid"}})
    new_cdr.should be_valid
  end

  it "should not be valid with a duplicate phone call id for the same type" do
    phone_call = create(:phone_call)
    inbound_cdr = create_cdr(:phone_call => phone_call)
    new_cdr.phone_call = inbound_cdr.phone_call
    new_cdr.should_not be_valid # because the new cdr is inbound as well
    new_cdr = build_cdr(:cdr_variables => {"variables" => {"direction" => "outbound"}})
    new_cdr.phone_call = phone_call
    new_cdr.should be_valid # because the new cdr is outbound
  end

  it "should not be valid without a duration" do
    cdr.duration = nil
    cdr.should_not be_valid
  end

  it "should not be valid without a bill_sec" do
    cdr.bill_sec = nil
    cdr.should_not be_valid
  end

  it_should_behave_like "communicable" do
    let(:communicable_resource) { cdr }
  end

  describe "callbacks" do
    describe "after initialize" do
      it "should set the type for type casting" do
        new_cdr.direction.should == "inbound" # from factory
        new_cdr.type.should == "InboundCdr"   # from factory
      end
    end

    describe "before_validation(:on => :create)" do
      it "should set the rest of the fields" do
        new_cdr.valid?
        new_cdr.bill_sec.should == 15         # from factory
        new_cdr.duration.should == 20         # from factory
        new_cdr.uuid.should be_present
      end
    end
  end

  describe "#typed" do
    subject { CallDataRecord.new }

    context "cdr has a valid type" do
      before do
        subject.type = "InboundCdr"
      end

      it "should return the typed version of the CDR" do
        subject.typed.should be_a(InboundCdr)
      end
    end

    context "cdr is invalid" do
      before do
        subject.type = nil
      end

      it "should return itself" do
        subject.typed.should be_a(CallDataRecord)
      end
    end
  end
end
