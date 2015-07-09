require 'rails_helper'

describe ChatExpirerJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:chat_expirer_queue]) }
  end

  describe "#perform(chat_id, mode)" do
    let(:chat) { double(Chat) }
    let(:mode) { "mode" }

    before do
      allow(chat).to receive(:expire!)
      allow(Chat).to receive(:find).and_return(chat)
    end

    it "should tell the chat to expire itself with the correct mode" do
      expect(chat).to receive(:expire!).with(mode)
      subject.perform(1, mode)
    end
  end
end
