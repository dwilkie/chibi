require 'rails_helper'

describe DeliveryReceiptUpdateStatusJob do
  it { expect(subject).not_to be_a(ActiveJob::Base) }

  describe ".sidekiq_options" do
    it { expect(described_class.sidekiq_options["queue"]).to eq(Rails.application.secrets[:smpp_delivery_receipt_update_status_queue]) }
  end

  describe "#perform(smsc_name, smsc_message_id, status)" do
    let(:reply) { double(Reply) }
    let(:smsc_message_id) { "7869576120333847249" }
    let(:smsc_name) { "SMART" }
    let(:status) { "FAILED" }

    before do
      allow(Reply).to receive(:token_find).with(smsc_message_id).and_return(reply)
      allow(reply).to receive(:delivery_status_updated_by_smsc!)
    end

    it "should tell the reply to update its state" do
      expect(reply).to receive(:delivery_status_updated_by_smsc!).with(smsc_name, status)
      subject.perform(smsc_name, smsc_message_id, status)
    end
  end
end
