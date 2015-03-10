require 'rails_helper'

describe CallDataRecord do
  include CdrHelpers

  let(:cdr) { create_cdr }
  let(:new_cdr) { build_cdr }

  describe "factory" do
    it "should be valid" do
      expect(cdr).to be_valid
    end
  end

  it "should not be valid without a direction" do
    cdr.direction = nil
    expect(cdr).not_to be_valid
  end

  it "should not be valid without a type" do
    cdr.type = nil
    expect(cdr).not_to be_valid
  end

  it "should not be valid with the wrong type" do
    cdr.type = "Foo"
    expect(cdr).not_to be_valid
  end

  it "should not be valid without a uuid" do
    cdr.uuid = nil
    expect(cdr).not_to be_valid
  end

  it "should not be valid with a duplicate uuid" do
    new_cdr.uuid = cdr.uuid
    expect(new_cdr).not_to be_valid
  end

  it "should be valid without an associated phone call" do
    new_cdr = build_cdr(:cdr_variables => {"variables" => {"uuid" => "invalid"}})
    expect(new_cdr).to be_valid
  end

  it "should not be valid with a duplicate phone call id for the same type" do
    phone_call = create(:phone_call)
    inbound_cdr = create_cdr(:phone_call => phone_call)
    new_cdr.phone_call = inbound_cdr.phone_call
    expect(new_cdr).not_to be_valid # because the new cdr is inbound as well
    new_cdr = build_cdr(:cdr_variables => {"variables" => {"direction" => "outbound"}})
    new_cdr.phone_call = phone_call
    expect(new_cdr).to be_valid # because the new cdr is outbound
  end

  it "should not be valid without a duration" do
    cdr.duration = nil
    expect(cdr).not_to be_valid
  end

  it "should not be valid without a bill_sec" do
    cdr.bill_sec = nil
    expect(cdr).not_to be_valid
  end

  it_should_behave_like "communicable" do
    let(:communicable_resource) { cdr }
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
