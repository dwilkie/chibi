require 'spec_helper'

describe ChatDeactivatorJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq("chat_deactivator_queue") }
  end

  describe "#perform(chat_id, options = {})" do
    let(:chat) { double(Chat) }
    let(:find_stub) { Chat.stub(:find) }

    before do
      allow(chat).to receive(:deactivate!)
      allow(Chat).to receive(:find).and_return(chat)
    end

    it "should tell the chat to deactivate itself" do
      expect(chat).to receive(:deactivate!).with(:some => :options)
      subject.perform(1, :some => :options)
    end
  end
end
