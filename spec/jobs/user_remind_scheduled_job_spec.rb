require 'rails_helper'

describe UserRemindScheduledJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:scheduled_queue]) }
  end

  describe "#perform" do
    before do
      allow(User).to receive(:remind!)
    end

    it "should remind users" do
      expect(User).to receive(:remind!)
      subject.perform
    end
  end
end
