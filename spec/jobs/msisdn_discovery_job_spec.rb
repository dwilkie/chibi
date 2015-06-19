require 'rails_helper'

describe MsisdnDiscoveryJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:msisdn_discovery_queue]) }
  end

  describe "#perform(msisdn_discovery_run_id, subscriber_number)" do
    let(:msisdn_discovery_run_id) { 1 }
    let(:msisdn_discovery_run) { double(MsisdnDiscoveryRun) }
    let(:subscriber_number) { 12345678 }

    before do
      allow(MsisdnDiscoveryRun).to receive(:find).with(msisdn_discovery_run_id).and_return(msisdn_discovery_run)
      allow(msisdn_discovery_run).to receive(:discover!)
    end

    it "should discover the MsisdnDiscoveryRun" do
      expect(msisdn_discovery_run).to receive(:discover!).with(subscriber_number)
      subject.perform(msisdn_discovery_run_id, subscriber_number)
    end
  end
end
