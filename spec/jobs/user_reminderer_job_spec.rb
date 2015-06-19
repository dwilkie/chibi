require 'rails_helper'

describe UserRemindererJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:user_reminderer_queue]) }
  end

  describe "#perform(user_id)" do
    let(:user) { double(User) }
    let(:user_id) { 1 }

    before do
      allow(user).to receive(:remind!)
      allow(User).to receive(:find).with(user_id).and_return(user)
    end

    it "should tell the user to remind himself" do
      expect(user).to receive(:remind!)
      subject.perform(user_id)
    end
  end
end
