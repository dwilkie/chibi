require 'rails_helper'

describe Rails.application.secrets[:smpp_mo_message_received_worker].constantize do
  describe ".sidekiq_options" do
    it { expect(described_class.sidekiq_options["queue"]).to eq(Rails.application.secrets[:smpp_mo_message_received_queue]) }
  end

  describe "#perform(smsc_name, source_address, dest_address, message_text)" do
    let(:message) { double(Message) }
    let(:channel) { "SMART" }
    let(:source_address) { "85512344592" }
    let(:dest_address) { "2442" }
    let(:message_text) { "Hi" }

    before do
      allow(Message).to receive(:from_smsc).and_return(message)
      allow(message).to receive(:save!)
      allow(message).to receive(:process)
    end

    it "should save and process the message" do
      expect(Message).to receive(:from_smsc).with(
        :channel => channel,
        :from => source_address,
        :to => dest_address,
        :body => message_text
      )
      expect(message).to receive(:save!)
      expect(message).to receive(:process!)
      subject.perform(channel, source_address, dest_address, message_text)
    end
  end
end
