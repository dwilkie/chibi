require 'rails_helper'

describe ChatExpirerJob do
  let(:options) { {"active_user" => true, "activate_new_chats" => true, "all" => true, "inactivity_period" => 24.hours.ago.to_s} }
  subject { described_class.new(options) }

  it "should be serializeable" do
    expect(subject.serialize["arguments"].first).to include(options)
  end

  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:chat_expirer_queue]) }
  end

  describe "#perform(options = {})" do
    before do
      allow(Chat).to receive(:end_inactive)
    end

    it "should end inactive chats" do
      expect(Chat).to receive(:end_inactive).with(options)
      subject.perform(options)
    end
  end
end
