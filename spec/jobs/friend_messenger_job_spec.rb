require 'rails_helper'

describe FriendMessengerJob do
  let(:options) { {"notify" => true, "between" => [6, 24], "notify_no_match" => false } }
  subject { described_class.new(options) }

  it "should be serializeable" do
    expect(subject.serialize["arguments"].first).to include(options)
  end

  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:friend_messenger_queue]) }
  end

  describe "#perform(user_id, options = {})" do
    let(:user) { double(User) }
    let(:user_id) { 1 }

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
