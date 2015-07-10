require 'rails_helper'

describe ReplyCleanupScheduledJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:scheduled_queue]) }
  end

  describe "#perform" do
    before do
      allow(Reply).to receive(:cleanup!)
    end

    it "should cleanup replies" do
      expect(Reply).to receive(:cleanup!)
      subject.perform
    end
  end
end
