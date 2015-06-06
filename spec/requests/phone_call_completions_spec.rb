require 'rails_helper'

describe "PhoneCallCompletions" do
  include PhoneCallHelpers
  include ActiveJobHelpers

  describe "POST /phone_call_completions.xml" do
    let(:phone_call) { create(:phone_call) }
    let(:call_duration) { 60 }

    before do
      trigger_job { complete_call(:call_sid => phone_call.sid, :call_duration => call_duration) }
      phone_call.reload
    end

    it "should set the duration and mark the call as completed" do
      expect(phone_call.duration).to eq(call_duration)
      expect(phone_call).to be_completed
    end
  end
end
