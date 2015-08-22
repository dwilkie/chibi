require 'rails_helper'

describe CallDataRecord do
  include CdrHelpers

  let(:cdr) { create_cdr }
  let(:new_cdr) { build_cdr }

  describe "validations" do
    describe "factory" do
      it "should be valid" do
        expect(cdr).to be_valid
      end
    end

    it { is_expected.to validate_presence_of(:direction) }
    it { is_expected.to validate_presence_of(:type) }
    it { is_expected.to validate_presence_of(:uuid) }
    it { is_expected.to validate_presence_of(:duration) }
    it { is_expected.to validate_presence_of(:bill_sec) }
    it { is_expected.to validate_inclusion_of(:type).in_array(["InboundCdr", "OutboundCdr",  "Chibi::Twilio::InboundCdr", "Chibi::Twilio::OutboundCdr"]) }

    it "should be valid without an associated phone call" do
      new_cdr = build_cdr(:cdr_variables => {"variables" => {"uuid" => "invalid"}})
      expect(new_cdr).to be_valid
    end

    context "uniqueness" do
      context "phone_call_id" do
        let(:phone_call) { create(:phone_call) }

        before do
          create_cdr(:phone_call => phone_call)
        end

        subject { build_cdr(:phone_call => phone_call) }

        it { is_expected.to validate_uniqueness_of(:phone_call_id).scoped_to(:type).allow_nil }
      end
    end
  end

  it_should_behave_like "communicable from user" do
    subject { cdr }
  end

  describe "callbacks" do
    subject { new_cdr }

    describe "after initialize" do
      it "should set the type for type casting" do
        expect(subject.direction).to eq("inbound") # from factory
        expect(subject.type).to eq("InboundCdr")   # from factory
      end
    end

    describe "before_validation(:on => :create)" do
      it "should set the rest of the fields" do
        subject.valid?
        expect(subject.bill_sec).to eq(15)         # from factory
        expect(subject.duration).to eq(20)         # from factory
        expect(subject.uuid).to be_present
        expect(subject.cdr_data.identifier).to eq("#{subject.uuid}.cdr.xml")
      end
    end

    describe "after_save" do
      it "should upload the cdr data to S3" do
        subject.save!
        uri = URI.parse(subject.cdr_data.url)
        expect(uri.host).to eq(Rails.application.secrets[:aws_fog_directory] + ".s3.amazonaws.com")
      end
    end
  end

  describe "#typed" do
    subject { CallDataRecord.new }

    context "cdr has a valid type" do
      before do
        subject.type = "InboundCdr"
      end

      it "should return the typed version of the CDR" do
        expect(subject.typed).to be_a(InboundCdr)
      end
    end

    context "cdr is invalid" do
      before do
        subject.type = nil
      end

      it "should return itself" do
        expect(subject.typed).to be_a(CallDataRecord)
      end
    end
  end
end
