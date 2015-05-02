require 'rails_helper'

describe "Call Data Records" do
  include AuthenticationHelpers
  include CdrHelpers
  include ActiveJobHelpers

  def post_call_data_record(options = {})
    post(
      call_data_records_path,
      {
        "cdr" => sample_cdr.body,
        "uuid" => "a_#{sample_cdr.uuid}"
      },
      authentication_params(:call_data_record)
    )
    expect(response.status).to be(options[:response] || 201)
  end

  describe "POST /call_data_records.xml" do
    def build_cdr(*args)
      cdr = super
      cdr.valid?
      cdr
    end

    shared_examples_for "creating a CDR" do
      let(:new_cdr) { CallDataRecord.find_by_uuid(sample_cdr.uuid) }

      def do_request(options = {})
        post_call_data_record
      end

      before do
        do_request
      end

      it "should create the CDR with the correct fields" do
        expect(new_cdr).to be_present
        expect(new_cdr).to be_valid
        expect(asserted_cdr_type.last).to eq(new_cdr)
      end
    end

    context "for an inbound cdr" do
      it_should_behave_like "creating a CDR" do
        let(:sample_cdr) { build_cdr(:cdr_variables => {"variables" => {"direction" => "inbound"} } ) }
        let(:asserted_cdr_type) { InboundCdr }
      end
    end

    context "for an outbound cdr" do
      it_should_behave_like "creating a CDR" do
        let(:sample_cdr) { build_cdr(:cdr_variables => {"variables" => {"direction" => "outbound"}} ) }
        let(:asserted_cdr_type) { OutboundCdr }
      end
    end

    context "for an outbound cdr with an invalid bridge_uid" do
      it_should_behave_like "creating a CDR" do
        let(:sample_cdr) { build_cdr(:cdr_variables => {"variables" => {"direction" => "outbound", "bridge_uuid" => "invalid"}})}
        let(:asserted_cdr_type) { OutboundCdr }
      end
    end
  end
end
