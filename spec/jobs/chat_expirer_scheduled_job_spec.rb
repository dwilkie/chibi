require 'rails_helper'

describe ChatExpirerScheduledJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:scheduled_queue]) }
  end

  describe "#perform(mode)" do
    let(:mode) { "mode" }

    before do
      allow(Chat).to receive(:expire!)
    end

    it "should expire chats with the correct mode" do
      expect(Chat).to receive(:expire!).with(mode)
      subject.perform(mode)
    end
  end
end
