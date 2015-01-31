require 'spec_helper'

describe ChargeRequestUpdaterJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq("critical") }
  end

  describe ".perform(charge_request_id, result, responder, reason = nil)" do
    let(:charge_request) { double(ChargeRequest) }
    let(:relation) { double(ActiveRecord::Relation) }
    let(:result) { "result" }
    let(:responder) { "responder" }
    let(:id) { 1 }
    let(:args) { [id, result, responder] }
    let(:finder_args) { {:id => id, :operator => responder} }

    before do
      allow(ChargeRequest).to receive(:where).with(finder_args).and_return(relation)
      allow(relation).to receive(:first!).and_return(charge_request)
      allow(charge_request).to receive(:set_result!)
    end

    it "should set the result on the charge request" do
      expect(charge_request).to receive(:set_result!).with(result, nil)
      subject.perform(*args)
    end
  end

  describe "performing the job" do
    # this is an integration test
    include TranslationHelpers
    include ActiveJobHelpers

    include_context "replies"

    let(:user) { create(:user) }
    let(:responder) { "qb" }
    let(:requester) { create(:message, :awaiting_charge_result, :user => user) }
    let(:charge_request) { create(:charge_request, :notify_requester, :requester => requester, :operator => responder) }

    before do
      charge_request
      clear_enqueued_jobs
    end

    def enqueue_job
      described_class.perform_later(charge_request.id, "failed", responder)
    end

    it "should update the charge request" do
      trigger_job { enqueue_job }
      reply_to(user).body.should == spec_translate(
        :not_enough_credit, user.locale
      )
    end
  end
end
