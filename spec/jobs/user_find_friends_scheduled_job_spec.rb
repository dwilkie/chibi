require 'rails_helper'

describe UserFindFriendsScheduledJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:scheduled_queue]) }
  end

  describe "#perform" do
    before do
      allow(User).to receive(:find_friends!)
    end

    it "should find friends for users" do
      expect(User).to receive(:find_friends!)
      subject.perform
    end
  end
end
