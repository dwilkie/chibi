require 'rails_helper'

describe MessagePartProcessorJob do
  it { expect(subject).to be_a(ActiveJob::Base) }

  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:message_part_processor_queue]) }
  end

  describe "#perform(message_part_id)" do
    let(:message_part_id) { 1 }
    let(:message_part) { double(MessagePart) }

    before do
      allow(MessagePart).to receive(:find).with(message_part_id).and_return(message_part)
      allow(message_part).to receive(:process!)
    end

    it "should tell the message part to process itself" do
      expect(message_part).to receive(:process!)
      subject.perform(message_part_id)
    end
  end
end
