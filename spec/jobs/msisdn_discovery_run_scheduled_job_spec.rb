require 'rails_helper'

describe MsisdnDiscoveryRunScheduledJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:scheduled_queue]) }
  end

  describe "#perform" do
    before do
      allow(MsisdnDiscoveryRun).to receive(:discover!)
    end

    it "should enqueue a msisdn discovery run" do
      expect(MsisdnDiscoveryRun).to receive(:discover!)
      subject.perform
    end
  end
end
