require 'rails_helper'

describe MsisdnDiscoveryRunCleanupScheduledJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:scheduled_queue]) }
  end

  describe "#perform" do
    before do
      allow(MsisdnDiscoveryRun).to receive(:cleanup!)
    end

    it "should cleanup msisdn discovery runs" do
      expect(MsisdnDiscoveryRun).to receive(:cleanup!)
      subject.perform
    end
  end
end
