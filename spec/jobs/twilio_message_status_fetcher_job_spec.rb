require 'rails_helper'

describe TwilioMessageStatusFetcherJob do
  it { expect(subject).to be_a(ActiveJob::Base) }

  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:twilio_message_status_fetcher_queue]) }
  end

  describe "#perform(reply_id)" do
    let(:reply_id) { 1 }
    let(:reply) { double(Reply) }

    before do
      allow(Reply).to receive(:find).with(reply_id).and_return(reply)
      allow(reply).to receive(:fetch_twilio_message_status!)
    end

    it "should retrieve the message status from Twilio" do
      expect(reply).to receive(:fetch_twilio_message_status!)
      subject.perform(reply_id)
    end
  end
end
