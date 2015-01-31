require 'spec_helper'

describe FriendFinderJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq("default") }
  end

  describe "#perform(options = {})" do
    let(:options) { {"some" => :options} }

    before do
      allow(User).to receive(:find_friends)
    end

    it "should find friends for users who need friends" do
      expect(User).to receive(:find_friends).with(options)
      subject.perform(options)
    end
  end
end
