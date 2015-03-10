require 'rails_helper'

describe LocatorJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq("high") }
  end

  describe "#perform(id, address)" do
    let(:location) { double(Location) }

    before do
      allow(Location).to receive(:find).with(1).and_return(location)
      allow(location).to receive(:locate!)
    end

    it "should tell the location to locate itself" do
      expect(location).to receive(:locate!).with("5 Park Lane")
      subject.perform(1, "5 Park Lane")
    end
  end
end
