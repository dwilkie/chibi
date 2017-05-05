require 'rails_helper'

describe Chibi::Twilio::OutboundCdr do
  let(:factory) { :outbound_twilio_cdr }

  describe "validation" do
    subject { build(factory) }
    it { expect(subject).to be_valid }
  end

  subject { described_class.new(:uuid => uuid) }
end

