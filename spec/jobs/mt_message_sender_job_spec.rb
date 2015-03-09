require 'rails_helper'

describe MtMessageSenderJob do
  it { expect(subject).to be_a(ActiveJob::Base) }

  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:smpp_internal_mt_message_queue]) }
  end

  describe "#perform(reply_id, smpp_server_id, source_address, dest_address, message_body)" do
    let(:reply_id) { 1 }
    let(:smpp_server_id) { "smart" }
    let(:source_address) { "2442" }
    let(:dest_address) { "85512239135" }
    let(:message_body) { "foo" }

    before do
      allow(MtMessageJobRunner).to receive(:perform_async)
    end

    it "should enqueue a job in the external smpp queue to send message" do
      expect(MtMessageJobRunner).to receive(:perform_async).with(
        reply_id.to_s,
        smpp_server_id,
        source_address,
        dest_address,
        message_body
      )

      subject.perform(reply_id, smpp_server_id, source_address, dest_address, message_body)
    end
  end
end
