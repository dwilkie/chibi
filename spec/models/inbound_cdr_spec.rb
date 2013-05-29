require 'spec_helper'

describe InboundCdr do

  let(:sample_cdr) { build(:call_data_record, :inbound) }
  let(:cdr) { CallDataRecord.create!(:body => sample_cdr.body).typed }
  subject { CallDataRecord.new(:body => sample_cdr.body).typed }

  describe "factory" do
    it "should be valid" do
      subject.should be_valid
    end
  end

  it "should not be valid without an associated phone call" do
    subject.uuid = "invalid"
    subject.should_not be_valid
  end

  it "should not be valid with a duplicate phone call id" do
    subject.phone_call = cdr.phone_call
    subject.should_not be_valid
  end

  it "should not be valid without a rfc2822 date" do
    cdr.rfc2822_date = nil
    cdr.should_not be_valid
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
