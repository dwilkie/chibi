require 'rails_helper'

describe Rails.application.secrets[:smpp_mo_message_received_worker].constantize do
  describe ".sidekiq_options" do
    it { expect(described_class.sidekiq_options["queue"]).to eq(Rails.application.secrets[:smpp_mo_message_received_queue]) }
  end

  describe "#perform(smsc_name, source_address, dest_address, message_text)" do
    include EnvHelpers

    let(:message) { double(Message) }
    let(:channel) { "SMART" }
    let(:source_address) { "85512344592" }
    let(:dest_address) { "2442" }
    let(:message_text) { "Hi" }

    before do
      stub_env(:smpp_mo_message_received_worker_enabled => worker_enabled)
      allow(Message).to receive(:from_smsc).and_return(message)
      allow(message).to receive(:save!)
      allow(message).to receive(:process)
    end

    def do_perform
      subject.perform(channel, source_address, dest_address, message_text)
    end

    context "given the worker is enabled" do
      let(:worker_enabled) { "1" }
      it "should save and process the message" do
        expect(Message).to receive(:from_smsc).with(
          :channel => channel,
          :from => source_address,
          :to => dest_address,
          :body => message_text
        )
        expect(message).to receive(:save!)
        expect(message).to receive(:process!)
        do_perform
      end
    end

    context "given the worker is disabled" do
      let(:worker_enabled) { nil }

      it "should do nothing" do
        expect(message).not_to receive(:process!)
        do_perform
      end
    end
  end
end
