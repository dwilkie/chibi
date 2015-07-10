require 'rails_helper'

describe ReplyHandleFailedScheduledJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:scheduled_queue]) }
  end

  describe "#perform" do
    before do
      allow(Reply).to receive(:handle_failed!)
    end

    it "should handle failed replies" do
      expect(Reply).to receive(:handle_failed!)
      subject.perform
    end
  end
end
