require 'rails_helper'

describe FriendFinderJob do
  let(:options) { {"notify" => true, "between" => [6, 24], "notify_no_match" => false } }
  subject { described_class.new(options) }

  it "should be serializeable" do
    expect(subject.serialize["arguments"].first).to eq(options)
  end

  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:friend_finder_queue]) }
  end

  describe "#perform(options = {})" do
    before do
      allow(User).to receive(:find_friends)
    end

    it "should find friends for users who need friends" do
      expect(User).to receive(:find_friends).with(options)
      subject.perform(options)
    end
  end
end
