require 'rails_helper'

describe UserCleanupJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:user_cleanup_queue]) }
  end

  describe "#perform(id)" do
    let(:user) { double(User) }
    let(:user_id) { 1 }

    before do
      allow(User).to receive(:find).with(user_id).and_return(user)
      allow(user).to receive(:logout!)
    end

    it "should tell the user to log himself out" do
      expect(user).to receive(:logout!)
      subject.perform(user_id)
    end
  end
end
