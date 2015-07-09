require 'rails_helper'

describe ChatCleanupScheduledJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:scheduled_queue]) }
  end

  describe "#perform" do
    before do
      allow(Chat).to receive(:cleanup!)
    end

    it "should cleanup all old chats" do
      expect(Chat).to receive(:cleanup!)
      subject.perform
    end
  end
end
