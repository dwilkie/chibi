require 'rails_helper'

describe MoMessageReceivedJob do
  it { expect(subject).not_to be_a(ActiveJob::Base) }

  describe ".sidekiq_options" do
    it { expect(described_class.sidekiq_options["queue"]).to eq(Rails.application.secrets[:smpp_mo_message_received_queue]) }
  end

  describe "#perform(smsc_name, source_address, dest_address, message_text)" do
    let(:message) { double(Message) }
    let(:channel) { "SMART" }
    let(:source_address) { "85512344592" }
    let(:dest_address) { "2442" }
    let(:message_text) { "Hi" }
    let(:csms_reference_num) { 0 }
    let(:csms_num_parts) { 1 }
    let(:csms_seq_num) { 1 }

    before do
      allow(Message).to receive(:from_smsc).and_return(message)
      allow(message).to receive(:save!)
      allow(message).to receive(:process)
    end

    def do_perform
      subject.perform(
        channel,
        source_address,
        dest_address,
        message_text,
        csms_reference_num,
        csms_num_parts,
        csms_seq_num
      )
    end

    it "should save and process the message" do
      expect(Message).to receive(:from_smsc).with(
        :channel => channel,
        :from => source_address,
        :to => dest_address,
        :body => message_text,
        :csms_reference_number => csms_reference_num,
        :number_of_parts => csms_num_parts,
        :sequence_number => csms_seq_num
      )
      expect(message).to receive(:save!)
      expect(message).to receive(:process!)
      do_perform
    end
  end
end
