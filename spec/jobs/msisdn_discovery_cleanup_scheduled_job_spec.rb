require 'rails_helper'

describe MsisdnDiscoveryCleanupScheduledJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:scheduled_queue]) }
  end

  describe "#perform" do
    before do
      allow(MsisdnDiscovery).to receive(:cleanup!)
    end

    it "should cleanup msisdn discoveries" do
      expect(MsisdnDiscovery).to receive(:cleanup!)
      subject.perform
    end
  end
end
