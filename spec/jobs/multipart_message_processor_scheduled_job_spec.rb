require 'rails_helper'

describe MultipartMessageProcessorScheduledJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:scheduled_queue]) }
  end

  describe "#perform" do
    before do
      allow(Message).to receive(:queue_unprocessed_multipart!)
    end

    it "should queue unprocessed multipart messages for processing" do
      expect(Message).to receive(:queue_unprocessed_multipart!)
      subject.perform
    end
  end
end
