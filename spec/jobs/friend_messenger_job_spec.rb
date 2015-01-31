require 'spec_helper'

describe FriendMessengerJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq("high") }
  end

  describe "#perform(user_id, options = {})" do
    let(:user) { double(User) }
    let(:user_id) { 1 }
    let(:options) { {"some" => :options} }

    before do
      allow(user).to receive(:find_friends!)
      allow(User).to receive(:find).with(user_id).and_return(user)
    end

    it "should find new friends for the user" do
      expect(user).to receive(:find_friends!).with(options)
      subject.perform(user_id, options)
    end
  end
end
