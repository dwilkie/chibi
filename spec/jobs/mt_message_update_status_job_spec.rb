require 'rails_helper'

describe MtMessageUpdateStatusJob do
  it { expect(subject).not_to be_a(ActiveJob::Base) }

  describe ".sidekiq_options" do
    it { expect(described_class.sidekiq_options["queue"]).to eq(Rails.application.secrets[:smpp_mt_message_update_status_queue]) }
  end

  describe "#perform(smsc_name, mt_message_id, smsc_message_id, status)" do
    let(:reply) { double(Reply) }
    let(:mt_message_id) { "1" }
    let(:smsc_message_id) { "7869576120333847249" }
    let(:smsc_name) { "SMART" }
    let(:status) { true }

    before do
      allow(Reply).to receive(:find).with(mt_message_id).and_return(reply)
      allow(reply).to receive(:delivered_by_smsc)
    end

    it "should mark the reply as delivered by the smsc" do
      expect(reply).to receive(:delivered_by_smsc!).with(smsc_name, smsc_message_id, status)
      subject.perform(smsc_name, mt_message_id, smsc_message_id, status)
    end
  end
end
