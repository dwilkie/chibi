require 'spec_helper'

describe ChatDeactivatorJob do
  let(:options) { {"active_user" => true, "activate_new_chats" => true, "all" => true, "inactivity_period" => 24.hours.ago.to_s} }
  subject { described_class.new(options) }

  it "should be serializeable" do
    expect(subject.serialize["arguments"].first).to eq(options)
  end

  describe "#queue_name" do
    it { expect(subject.queue_name).to eq("high") }
  end

  describe "#perform(chat_id, options = {})" do
    let(:chat) { double(Chat) }
    let(:find_stub) { Chat.stub(:find) }

    before do
      allow(chat).to receive(:deactivate!)
      allow(Chat).to receive(:find).and_return(chat)
    end

    it "should tell the chat to deactivate itself" do
      expect(chat).to receive(:deactivate!).with(options)
      subject.perform(1, options)
    end
  end
end
