require 'rails_helper'

describe TwilioCdrFetcherJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq("high") }
  end

  describe "#perform(phone_call_id)" do
    let(:phone_call) { double(PhoneCall) }

    before do
      allow(PhoneCall).to receive(:find).and_return(phone_call)
    end

    it "should tell the phone call to fetch it's own CDR from Twilio" do
      expect(phone_call).to receive(:fetch_inbound_twilio_cdr!)
      expect(phone_call).to receive(:fetch_outbound_twilio_cdr!)
      subject.perform(1)
    end
  end
end
