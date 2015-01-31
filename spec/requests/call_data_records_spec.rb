require 'spec_helper'

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
    response.status.should be(options[:response] || 201)
  end

  describe "POST /call_data_records.xml" do
    def build_cdr(*args)
      cdr = super
      cdr.valid?
      cdr
    end

    shared_examples_for "creating a CDR" do
      def do_request(options = {})
        trigger_job(options) { post_call_data_record }
      end

      it "should queue a job for saving the CDR and return immediately" do
        do_request(:queue_only => true)
        expect(enqueued_jobs.size).to eq(1)
        job = enqueued_jobs.first
        expect(job[:args].first).to eq(sample_cdr.body)
        expect(job[:queue]).to eq("call_data_record_creator_queue")
      end

      context "when the job is run" do
        let(:new_cdr) { CallDataRecord.find_by_uuid(sample_cdr.uuid) }

        before do
          do_request
        end

        it "should create the CDR with the correct fields" do
          new_cdr.should be_present
          new_cdr.should be_valid
          asserted_cdr_type.last.should == new_cdr
        end
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
