require 'rails_helper'

describe PhoneCallCompletionJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:phone_call_completion_queue]) }
  end

  describe "#perform(params = {})" do
    let(:call_params) { { "Foo" => "Bar" } }

    before do
      allow(PhoneCall).to receive(:complete!)
    end

    it "should tell the phone call to complete itself" do
      expect(PhoneCall).to receive(:complete!).with(call_params)
      subject.perform(call_params)
    end
  end
end
