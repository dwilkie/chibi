require 'rails_helper'

describe MsisdnDiscoveryJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:msisdn_discovery_queue]) }
  end

  describe "#perform(mobile_number)" do
    let(:scope) { double(ActiveRecord::Relation) }
    let(:msisdn) { double(Msisdn) }
    let(:mobile_number) { generate(:mobile_number) }

    before do
      allow(Msisdn).to receive(:where).with(:mobile_number => mobile_number).and_return(scope)
      allow(scope).to receive(:first_or_create!).and_return(msisdn)
      allow(msisdn).to receive(:discover!)
    end

    it "should discover the msisdn" do
      expect(msisdn).to receive(:discover!)
      subject.perform(mobile_number)
    end
  end
end
