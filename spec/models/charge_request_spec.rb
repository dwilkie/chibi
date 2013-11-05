require 'spec_helper'

describe ChargeRequest do
  subject { create(:charge_request) }

  describe "factory" do
    it "should be valid" do
      subject.should be_valid
    end
  end

  describe "validations" do
    it "should not be valid without an associated user" do
      subject.user = nil
      subject.should_not be_valid
    end

    it "should not be valid without an operator" do
      subject.operator = nil
      subject.should_not be_valid
    end
  end

  describe "callbacks" do
    describe "after_create" do
      include ResqueHelpers

      let(:job) { ResqueSpec.queues["charge_requester_queue"].first }

      it "should queue a job for processing the charge request" do
        do_background_task(:queue_only => true) { subject }

        job.should_not be_nil
        job[:class].should == "ChargeRequester"
        job[:args].should == [subject.id, subject.operator, subject.user.mobile_number]
      end
    end
  end
end
