require 'rails_helper'

module Chibi
  module Twilio
    describe OutboundCdr do
      include PhoneCallHelpers::TwilioHelpers

      let(:uuid) { generate(:guid) }
      let(:related_user) { create(:user) }
      let(:related_phone_call) { create(:phone_call) }

      subject { Chibi::Twilio::OutboundCdr.new(:uuid => uuid) }

      it "should be valid" do
        expect_twilio_cdr_fetch(
          :call_sid => uuid, :to => related_user.mobile_number,
          :direction => :outbound, :parent_call_sid => related_phone_call.sid
        ) { expect(subject).to be_valid }
      end

      it_should_behave_like "a Chibi Twilio CDR" do
        let(:klass) { Chibi::Twilio::OutboundCdr }
        let(:direction) { :outbound }
        let(:assertions) {
          {"direction" => "outbound", "sip_to_user" => true, "bridge_uuid" => true}
        }
      end
    end
  end
end
