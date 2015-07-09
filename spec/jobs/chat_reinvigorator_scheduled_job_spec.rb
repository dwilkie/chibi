require 'rails_helper'

describe ChatReinvigoratorScheduledJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:scheduled_queue]) }
  end

  describe "#perform" do
    before do
      allow(Chat).to receive(:reinvigorate!)
    end

    it "should reinvigorate all stagnant chats" do
      expect(Chat).to receive(:reinvigorate!)
      subject.perform
    end
  end
end
