require 'spec_helper'

describe CallDataRecord do

  let(:new_cdr) { build(:call_data_record) }
  let(:cdr) { create(:call_data_record) }

  describe "factory" do
    it "should be valid" do
      new_cdr.should be_valid
    end
  end

  it "should not be valid without a body" do
    new_cdr.body = nil
    new_cdr.should_not be_valid
  end

  it "should not be valid without an associated phone call" do
    new_cdr.uuid = "invalid"
    new_cdr.should_not be_valid
  end

  it "should not be valid with a duplicate phone call id" do
    cdr
    new_cdr.phone_call = cdr.phone_call
    new_cdr.should_not be_valid
  end

  it "should not be valid without a uuid" do
    cdr.uuid = nil
    cdr.should_not be_valid
  end

  it "should not be valid with a duplicate uuid" do
    cdr
    new_cdr.uuid = cdr.uuid
    new_cdr.should_not be_valid
  end

  it "should not be valid without a duration" do
    cdr.duration = nil
    cdr.should_not be_valid
  end

  it "should not be valid without a bill_sec" do
    cdr.bill_sec = nil
    cdr.should_not be_valid
  end

  it "should not be valid without a rfc2822 date" do
    cdr.rfc2822_date = nil
    cdr.should_not be_valid
  end

  describe "callbacks" do
    describe "before validation on create" do
      it "should correctly populate the required attributes" do
        Timecop.freeze(Time.now) do
          new_cdr.valid?
          new_cdr.bill_sec.should == 15 # from factory
          new_cdr.duration.should == 20 # from factory
          new_cdr.uuid.should == new_cdr.phone_call.sid
          new_cdr.rfc2822_date.to_i.should == Time.now.to_i
        end
      end
    end
  end
end
