require 'spec_helper'

describe ChargeRequest do
  subject { create(:charge_request) }
  let(:skip_callback_request_charge) { false }

  def create_charge_request(*args)
    options = args.extract_options!
    create(:charge_request, *args, options)
  end

  before do
    ChargeRequest.skip_callback(:create, :after, :request_charge!) if skip_callback_request_charge
  end

  after do
    ChargeRequest.set_callback(:create, :after, :request_charge!)
  end

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

  describe ".timeout!" do
    let(:time_considered_old) { 24.hours }
    let(:skip_callback_request_charge) { true }

    let(:old_charge_request_awaiting_result) { create_charge_request(:awaiting_result) }
    let(:charge_request_awaiting_result) { create_charge_request(:awaiting_result, :updated_at => 23.hours.ago) }
    let(:old_charge_request_errored) { create_charge_request(:errored) }
    let(:old_charge_request_failed) { create_charge_request(:failed) }
    let(:old_charge_request_successful) { create_charge_request(:successful) }
    let(:old_charge_request_created) { create_charge_request }

    def create_charge_request(*args)
      options = args.extract_options!
      super(*args, {:updated_at => time_considered_old.ago, :created_at => time_considered_old.ago}.merge(options))
    end

    before do
      charge_request_awaiting_result
      old_charge_request_awaiting_result
      old_charge_request_errored
      old_charge_request_failed
      old_charge_request_successful
      old_charge_request_created
    end

    it "should only mark old charge requests that are 'awaiting_result' or 'created' as 'errored'" do
      subject.class.timeout!
      charge_request_awaiting_result.reload.should be_awaiting_result
      old_charge_request_awaiting_result.reload.should be_errored
      old_charge_request_awaiting_result.reason.should == "timeout"
      old_charge_request_errored.reload.should be_errored
      old_charge_request_failed.reload.should be_failed
      old_charge_request_successful.reload.should be_successful
      old_charge_request_created.reload.should be_errored
      old_charge_request_created.reason.should == "timeout"
    end
  end

  describe "#slow?" do

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
      let(:skip_callback_request_charge) { true }

      it_should_behave_like "determining if a charge request is slow"
    end

    context "the charge request is 'awaiting_confirmation'" do
      def create_charge_request(options = {})
        super(:awaiting_result, options)
      end

      it_should_behave_like "determining if a charge request is slow"
    end
  end

  describe "#set_result!(result, reason)" do
    SAMPLE_RESULTS = {
      "successful" => {:reason => nil},
      "failed" => {:reason => "insufficient_funds"},
      "error" => {:reason => "bad_request", :asserted_state => "errored"}
    }

    SAMPLE_RESULTS.each do |result, assertions|
      context "where result: '#{result}', reason: '#{assertions[:reason]}'" do
        def do_set_result!(result, assertions)
          subject.set_result!(result, assertions[:reason])
        end

        context "state is 'awaiting_result'" do
          it "should update the charge request's result, reason and state" do
            do_set_result!(result, assertions)
            subject.reload
            subject.state.should == (assertions[:asserted_state] || result)
            subject.result.should == result
            subject.reason.should == assertions[:reason]
          end

          context "requester is set" do
            let(:requester) { create(:message) }

            context "notify_requester is 'true'" do
              subject { create(:charge_request, :notify_requester, :requester => requester) }

              it "should notify the requester" do
                requester.should_receive(:charge_request_updated!)
                do_set_result!(result, assertions)
              end
            end

            context "notify_requester is 'false'" do
              subject { create(:charge_request, :requester => requester) }

              it "should not notify the requester" do
                requester.should_not_receive(:charge_request_updated!)
                do_set_result!(result, assertions)
              end
            end
          end
        end

        context "state is 'successful'" do
          subject { create(:charge_request, :successful) }

          it "should not update the charge request" do
            previous_result = subject.result
            previous_reason = subject.reason
            do_set_result!(result, assertions)
            subject.reload
            subject.should be_successful
            subject.result.should == previous_result
            subject.reason.should == previous_reason
          end
        end
      end
    end
  end

  describe "callbacks" do
    describe "after_create" do
      subject { build(:charge_request) }

      include ResqueHelpers

      let(:job) { ResqueSpec.queues[ENV["CHIBI_BILLER_CHARGE_REQUEST_QUEUE"]].first }

      before do
        do_background_task(:queue_only => true) { subject.save! }
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
