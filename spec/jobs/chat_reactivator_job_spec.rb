require 'spec_helper'

describe ChatReactivatorJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq("chat_reactivator_queue") }
  end

  describe "#perform(chat_id)" do
    let(:chat) { double(Chat) }
    let(:chat_id) { 1 }

    before do
      allow(chat).to receive(:reinvigorate!)
      allow(Chat).to receive(:find).with(chat_id).and_return(chat)
    end

    it "should tell the chat to reinvigorate itself" do
      expect(chat).to receive(:reinvigorate!)
      subject.perform(chat_id)
    end
  end
end
