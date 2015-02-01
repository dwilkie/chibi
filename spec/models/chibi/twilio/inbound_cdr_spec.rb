require 'rails_helper'

module Chibi
  module Twilio
    describe InboundCdr do
      include PhoneCallHelpers::TwilioHelpers

      let(:uuid) { related_phone_call.sid }
      let(:related_user) { create(:user) }
      let(:related_phone_call) { create(:phone_call, :user => related_user) }

      subject { Chibi::Twilio::InboundCdr.new(:uuid => uuid) }

      def expect_twilio_cdr_fetch(options = {}, &block)
        super({:call_sid => uuid, :from => related_user.mobile_number}.merge(options), &block)
      end

      it "should be valid" do
        expect_twilio_cdr_fetch { subject.should be_valid }
      end

      describe "associations" do
        describe "#outbound_cdrs" do
          it "should have_many" do
            expect_twilio_cdr_fetch do
              relation = subject.outbound_cdrs
              relation.should be_empty
              relation.to_sql.should =~ /Chibi::Twilio::OutboundCdr/
            end
          end
        end
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
