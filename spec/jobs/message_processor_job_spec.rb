require 'rails_helper'

describe MessageProcessorJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:message_processor_queue]) }
  end

  describe "#perform(message_id)" do
    let(:message) { double(Message) }
    let(:message_id) { 1 }

    before do
      allow(message).to receive(:pre_process!)
      allow(Message).to receive(:find).with(message_id).and_return(message)
    end

    it "should tell the message to process itself" do
      expect(message).to receive(:pre_process!)
      subject.perform(message_id)
    end
  end

  describe "automatic retries" do
    include ActiveJobHelpers
    it { expect { trigger_job { described_class.perform_later(-1) } }.not_to raise_error }
  end
end
