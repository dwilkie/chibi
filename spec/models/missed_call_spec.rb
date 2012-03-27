require 'spec_helper'

describe MissedCall do

  let(:new_missed_call) { build(:missed_call) }

  describe "factory" do
    it "should be valid" do
      new_missed_call.should be_valid
    end
  end

  it_should_behave_like "communicable" do
    let(:communicable_resource) { new_missed_call }
  end

  describe "assigning a user" do
    it "should use the parsed mobile number when assigning the user" do
      missed_call = subject.class.new(:subject => new_missed_call.subject)
      missed_call.user.mobile_number.should == new_missed_call.user.mobile_number
    end
  end

  [:subject, :message].each do |attribute|
    describe "##{attribute}" do
      it "should be an accessor" do
        subject.send("#{attribute}=", attribute)
        subject.send(attribute).should == attribute
      end

      it "should be mass assignable" do
        new_missed_call = subject.class.new(attribute => attribute)
        new_missed_call.send(attribute).should == attribute
      end
    end

    describe "##{attribute}=" do
      it "should try extract the origin from the #{attribute}" do
        subject.send("#{attribute}=", "missed call from 012344566 today")
        subject.from.should == "85512344566"
        subject.send("#{attribute}=", "missed call from 85512344500")
        subject.from.should == "85512344500"
        subject.send("#{attribute}=", "blah +85512344556 blah blah ")
        subject.from.should == "85512344556"
      end
    end
  end

  describe "#return_call!" do
    include MissedCallHelpers

    it "should return the missed call" do
      expect_call(:to => new_missed_call.from) do
        new_missed_call.return_call!
      end
    end
  end
end
