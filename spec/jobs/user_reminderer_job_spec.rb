require 'spec_helper'

describe UserRemindererJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq("user_reminderer_queue") }
  end

  describe "#perform(user_id, options = {})" do
    let(:user) { double(User) }
    let(:user_id) { 1 }
    let(:options) { {"some" => :options} }

    before do
      allow(user).to receive(:remind!)
      allow(User).to receive(:find).with(user_id).and_return(user)
    end

    it "should tell the user to remind himself" do
      expect(user).to receive(:remind!).with(options)
      subject.perform(user_id, options)
    end
  end
end
