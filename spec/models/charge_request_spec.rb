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

  describe "#slow?" do
    def create_charge_request(*args)
      options = args.extract_options!
      create(:charge_request, *args, options)
    end

    let(:default_timeout) { 5.seconds }

    shared_examples_for "determining if a charge request is slow" do
      subject { create_charge_request }

      context "no timeout is specified" do
        context "charge request was last updated less than 5 seconds ago" do
          it "should return false" do
            subject.should_not be_slow
          end
        end

        context "charge request was last updated more than 5 seconds ago" do
          subject { create_charge_request(:updated_at => default_timeout.ago) }

          it "should return true" do
            subject.should be_slow
          end
        end
      end
    end

    context "the charge request is not 'created' or 'awaiting_confirmation'" do
      it "should return true" do
        create_charge_request(:successful).should be_slow
      end
    end

    context "the charge request is 'created'" do
      it_should_behave_like "determining if a charge request is slow"
    end

    context "the charge request is 'awaiting_confirmation'" do
      def create_charge_request(options = {})
        super(:awaiting_result, options)
      end

      it_should_behave_like "determining if a charge request is slow"
    end
  end

  describe "callbacks" do
    describe "after_create" do
      include ResqueHelpers

      let(:job) { ResqueSpec.queues[ENV["CHIBI_BILLER_CHARGE_REQUEST_QUEUE"]].first }

      before do
        do_background_task(:queue_only => true) { subject }
      end

      it "should queue a job for processing the charge request" do
        job.should_not be_nil
        job[:class].should == ENV["CHIBI_BILLER_CHARGE_REQUEST_WORKER"]
        job[:args].should == [subject.id, subject.operator, subject.user.mobile_number]
      end

      it "should mark the charge_request as 'awaiting_result'" do
        subject.reload.should be_awaiting_result
      end
    end
  end
end
