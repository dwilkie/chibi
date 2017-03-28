require 'rails_helper'

describe Chibi::Twilio::InboundCdr do
  include PhoneCallHelpers::TwilioHelpers
  let(:factory) { :inbound_twilio_cdr }

  let(:uuid) { related_phone_call.sid }
  let(:related_user) { create(:user) }
  let(:related_phone_call) { create(:phone_call, :user => related_user) }

  describe "validation" do
    subject { build(factory) }
    it { expect(subject).to be_valid }
  end

  describe "associations" do
    it { is_expected.to have_many(:outbound_cdrs).class_name("Chibi::Twilio::OutboundCdr") }
  end

  describe "#fetch!", :vcr, :cassette => "twilio/get_inbound_call", :vcr_options => {:match_requests_on => [:method, :twilio_api_request]} do
    include EnvHelpers

    let(:twilio_account_sid) { "twilio-account-sid" }
    let(:twilio_auth_token) { "twilio-auth-token" }
    let(:sid) { "CAbcff7efa7dbcad4e8b2615fa065b54b9" }

    let(:phone_call) { create(:phone_call, :sid => sid) }

    subject { described_class.new(:uuid => sid) }
    let(:request) { WebMock.requests.last }

    def setup_scenario
      stub_env(:twilio_account_sid => twilio_account_sid, :twilio_auth_token => twilio_auth_token)
      phone_call
      subject.fetch!
    end

    before do
      setup_scenario
      subject.fetch!
    end

    def assert_fetch!
      expect(request).to be_present
      # from cassette results
      is_expected.to be_inbound
      expect(subject.rfc2822_date).to eq(Time.parse("Mon, 27 Mar 2017 10:36:03 +0000"))
      expect(subject.duration).to eq(38)
      expect(subject.bill_sec).to eq(38)
      expect(subject.from).to eq("61401435255")
      expect(subject.phone_call).to eq(phone_call)
      is_expected.to be_valid
    end

    it { assert_fetch! }
  end
end
