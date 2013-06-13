require 'spec_helper'

module Chibi
  module Twilio
    describe InboundCdr do
      include PhoneCallHelpers::TwilioHelpers

      let(:uuid) { related_phone_call.sid }
      let(:related_user) { create(:user) }
      let(:related_phone_call) { create(:phone_call, :user => related_user) }

      subject { Chibi::Twilio::InboundCdr.new(:uuid => uuid) }

      it "should be valid" do
        expect_twilio_cdr_fetch(
          :call_sid => uuid, :from => related_user.mobile_number
        ) { subject.should be_valid }
      end

      it_should_behave_like "a Chibi Twilio CDR" do
        let(:klass) { Chibi::Twilio::InboundCdr }
        let(:direction) { "inbound" }
        let(:assertions) {
          {"direction" => "inbound", "sip_from_user" => true, "RFC2822_DATE" => true}
        }
      end
    end
  end
end
