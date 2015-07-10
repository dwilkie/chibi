require 'rails_helper'

describe ChargeRequestTimeoutScheduledJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:scheduled_queue]) }
  end

  describe "#perform" do
    before do
      allow(ChargeRequest).to receive(:timeout!)
    end

    it "should timeout old charge requests" do
      expect(ChargeRequest).to receive(:timeout!)
      subject.perform
    end
  end
end
