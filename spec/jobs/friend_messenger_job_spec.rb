require 'rails_helper'

describe FriendMessengerJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:friend_messenger_queue]) }
  end

  describe "#perform(user_id)" do
    let(:user) { double(User) }
    let(:user_id) { 1 }

    before do
      allow(user).to receive(:find_friends!)
      allow(User).to receive(:find).with(user_id).and_return(user)
    end

    it "should find new friends for the user" do
      expect(user).to receive(:find_friends!)
      subject.perform(user_id)
    end
  end
end
