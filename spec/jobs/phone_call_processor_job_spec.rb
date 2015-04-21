require 'rails_helper'

describe PhoneCallProcessorJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:phone_call_processor_queue]) }
  end

  describe "#perform(phone_call_id, call_params, request_url)" do
    let(:phone_call) { double(PhoneCall) }
    let(:phone_call_id) { 1 }
    let(:call_params) { { "Foo" => "Bar" } }
    let(:request_url) { "https://example.com/phone_calls.xml" }

    before do
      allow(phone_call).to receive(:set_call_params)
      allow(phone_call).to receive(:process!)
      allow(PhoneCall).to receive(:find).with(phone_call_id).and_return(phone_call)
    end

    it "should tell the phone call to process itself" do
      expect(phone_call).to receive(:set_call_params).with(call_params, request_url)
      expect(phone_call).to receive(:process!)
      subject.perform(phone_call_id, call_params, request_url)
    end
  end
end
