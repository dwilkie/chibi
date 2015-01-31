require 'spec_helper'

describe ChatReinvigoratorJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq("default") }
  end

  describe "#perform" do
    before do
      allow(Chat).to receive(:reinvigorate!)
    end

    it "should reactivate all stagnant chats" do
      expect(Chat).to receive(:reinvigorate!)
      subject.perform
    end
  end
end
