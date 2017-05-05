require 'rails_helper'

describe CallDataRecord::Twilio do
  let(:factory) { :twilio_cdr }

  describe "validation" do
    subject { build(factory) }
    it { expect(subject).to be_valid }
  end

  include_examples "call_data_record"

  describe "#fetch!", :vcr, :vcr_options => {:match_requests_on => [:method, :twilio_api_request]} do
    include EnvHelpers

    let(:twilio_account_sid) { "twilio-account-sid" }
    let(:twilio_auth_token) { "twilio-auth-token" }
    let(:recorded_parameters) {  attributes_for(factory, sid_trait) }
    let(:sid) { recorded_parameters[:sid] }

    subject { described_class.new(:uuid => sid) }
    let(:request) { WebMock.requests.last }

    def setup_scenario
      stub_env(:twilio_account_sid => twilio_account_sid, :twilio_auth_token => twilio_auth_token)
      subject.fetch!
    end

    before do
      setup_scenario
      subject.fetch!
    end

    def assert_fetch!
      expect(request).to be_present
      is_expected.to be_valid
    end

    context "for inbound call",  :cassette => "twilio/get_inbound_call" do
      let(:sid_trait) { :with_recorded_inbound_sid }
      let(:phone_call) { create(:phone_call, :sid => sid) }

      def setup_scenario
        phone_call
        super
      end

      def assert_fetch!
        super
        is_expected.to be_inbound
        expect(subject.phone_call).to eq(phone_call)
        # from cassette results
        expect(subject.rfc2822_date).to eq(Time.parse("Mon, 27 Mar 2017 10:36:03 +0000"))
        expect(subject.duration).to eq(38)
        expect(subject.bill_sec).to eq(38)
        expect(subject.from).to eq("61401435255")
      end

      it { assert_fetch! }
    end

    context "for outbound call", :cassette => "twilio/get_outbound_call" do
      let(:sid_trait) { :with_recorded_outbound_sid }
      let(:parent_call_sid) { recorded_parameters[:parent_call_sid] }
      let(:inbound_cdr) { create(factory, :inbound, :uuid => parent_call_sid) }

      def setup_scenario
        inbound_cdr
      end

      def assert_fetch!
        super
        is_expected.to be_outbound
        expect(subject.phone_call).to eq(nil)
        # from cassette results
        expect(subject.bridge_uuid).to eq(parent_call_sid)
        expect(subject.inbound_cdr).to eq(inbound_cdr)
        expect(subject.rfc2822_date).to eq(
          Time.parse(
            "Mon, 24 Apr 2017 14:04:23 +00:00"
          )
        )
        expect(subject.inbound_cdr)
        expect(subject.duration).to eq(60)
        expect(subject.bill_sec).to eq(60)
        expect(subject.from).to eq("855966865371")
      end

      it { assert_fetch! }
    end
  end
end
