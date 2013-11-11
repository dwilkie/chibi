require 'spec_helper'

describe ChargeRequestUpdater do
  let(:asserted_queue) { :charge_request_updater }

  context "@queue" do
    it "should == :charge_request_updater_queue" do
      subject.class.instance_variable_get(:@queue).should == asserted_queue
    end
  end

  describe ".perform(charge_request_id, result, reason)" do
    let(:charge_request) { mock_model(ChargeRequest) }
    let(:find_stub) { ChargeRequest.stub(:find) }
    let(:result) { "result" }
    let(:args) { [1, result] }

    before do
      charge_request.stub(:update!)
      find_stub.and_return(charge_request)
    end

    it "should update the charge request" do
      charge_request.should_receive(:set_result!).with(result, nil)
      subject.class.perform(*args)
    end

    it_should_behave_like "rescheduling SIGTERM exceptions"
  end

  describe "performing the job" do
    # this is an integration test

    include ResqueHelpers
    include TranslationHelpers
    include_context "replies"

    let(:user) { create(:user) }
    let(:requester) { create(:message, :awaiting_charge_result, :user => user) }
    let(:charge_request) { create(:charge_request, :notify_requester, :requester => requester) }

    def enqueue_job
      Resque.enqueue(ChargeRequestUpdater, charge_request.id, "failed")
    end

    it "should update the charge request" do
      do_background_task { enqueue_job }
      perform_background_job(asserted_queue)
      perform_background_job(:message_processor_queue)
      reply_to(user).body.should == spec_translate(
        :not_enough_credit, user.locale
      )
    end
  end
end
