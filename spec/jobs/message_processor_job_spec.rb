require 'rails_helper'

describe MessageProcessorJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:message_processor_queue]) }
  end

  describe "#perform(message_id)" do
    let(:message) { double(Message) }
    let(:message_id) { 1 }

    before do
      allow(message).to receive(:process!)
      allow(Message).to receive(:find).with(message_id).and_return(message)
    end

    it "should tell the message to process itself" do
      expect(message).to receive(:process!)
      subject.perform(message_id)
    end
  end
end
