require 'rails_helper'

describe TwilioMtMessageReceivedJob do
  it { expect(subject).to be_a(ActiveJob::Base) }

  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:twilio_mt_message_received_queue]) }
  end

  describe "#perform(reply_id)" do
    let(:reply_id) { 1 }
    let(:reply) { double(Reply) }

    before do
      allow(Reply).to receive(:find).with(reply_id).and_return(reply)
      allow(reply).to receive(:delivered_by_twilio!)
    end

    it "should tell the reply that the mt message was received by twilio" do
      expect(reply).to receive(:delivered_by_twilio!)
      subject.perform(reply_id)
    end
  end
end
