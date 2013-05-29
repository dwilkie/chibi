require 'spec_helper'

describe CallDataRecord do

  let(:sample_cdr) { build(:call_data_record) }
  let(:cdr) { CallDataRecord.create!(:body => sample_cdr.body) }
  subject { CallDataRecord.new(:body => sample_cdr.body) }

  describe "factory" do
    it "should be valid" do
      subject.should be_valid
    end
  end

  it "should not be valid without a body" do
    subject.body = nil
    subject.should_not be_valid
  end

  it "should not be valid without a direction" do
    subject.direction = nil
    subject.should_not be_valid
  end

  it "should not be valid without a type" do
    subject.type = nil
    subject.should_not be_valid
  end

  it "should not be valid with the wrong type" do
    subject.type = "Foo"
    subject.should_not be_valid
  end

  it "should not be valid without a uuid" do
    subject.uuid = nil
    subject.should_not be_valid
  end

  it "should not be valid with a duplicate uuid" do
    cdr
    subject.uuid = cdr.uuid
    subject.should_not be_valid
  end

  it "should not be valid without a duration" do
    subject.duration = nil
    subject.should_not be_valid
  end

  it "should not be valid without a bill_sec" do
    subject.bill_sec = nil
    subject.should_not be_valid
  end

  describe "callbacks" do
    describe "after initialize" do
      it "should correctly populate the required attributes" do
        subject.direction.should == "inbound" # from factory
        subject.type.should == "InboundCdr"   # from factory
        subject.bill_sec.should == 15         # from factory
        subject.duration.should == 20         # from factory
        subject.uuid.should be_present
      end
    end
  end

  describe "#typed" do
    context "cdr is valid" do
      it "should return the typed version of the CDR" do
        subject.typed.should be_a(InboundCdr) # From factory
      end
    end

    context "cdr is invalid" do
      before do
        subject.direction = nil
      end

      it "should return itself" do
        subject.typed.should be_a(CallDataRecord)
      end
    end
  end
end
