require 'spec_helper'

describe ChargeRequestUpdater do
  let(:asserted_queue) { :charge_request_updater_queue }

  context "@queue" do
    it "should == :charge_request_updater_queue" do
      subject.class.instance_variable_get(:@queue).should == asserted_queue
    end
  end

  describe ".perform(charge_request_id, result, responder, reason = nil)" do
    let(:charge_request) { mock_model(ChargeRequest) }
    let(:find_stub) { ChargeRequest.stub(:where) }
    let(:relation) { double(ActiveRecord::Relation) }
    let(:result) { "result" }
    let(:responder) { "responder" }
    let(:id) { 1 }
    let(:args) { [id, result, responder] }

    before do
      find_stub.and_return(relation)
      relation.stub(:first!).and_return(charge_request)
      charge_request.stub(:set_result!)
    end

    it "should set the result on the charge request" do
      ChargeRequest.should_receive(:where).with(:id => id, :operator => responder)
      relation.should_receive(:first!)
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
    let(:responder) { "qb" }
    let(:requester) { create(:message, :awaiting_charge_result, :user => user) }
    let(:charge_request) { create(:charge_request, :notify_requester, :requester => requester, :operator => responder) }

    def enqueue_job
      Resque.enqueue(ChargeRequestUpdater, charge_request.id, "failed", responder)
    end

    it "should update the charge request" do
      do_background_task(:queue_only => true) { enqueue_job }
      perform_background_job(asserted_queue)
      perform_background_job(:message_processor_queue)
      reply_to(user).body.should == spec_translate(
        :not_enough_credit, user.locale
      )
    end
  end
end
