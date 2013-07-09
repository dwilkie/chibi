require 'spec_helper'

describe "Call Data Records" do
  include AuthenticationHelpers
  include ResqueHelpers
  include CdrHelpers

  def post_call_data_record(options = {})
    queue_only = options.delete(:queue_only)
    do_background_task(:queue_only => queue_only) do
      post call_data_records_path, {
        "cdr" => sample_cdr.body,
        "uuid" => "a_#{sample_cdr.uuid}"
      },
      authentication_params(:call_data_record)
      response.status.should be(options[:response] || 201)
    end
  end

  describe "POST /call_data_records.xml" do
    def build_cdr(*args)
      cdr = super
      cdr.valid?
      cdr
    end

    shared_examples_for "creating a CDR" do
      before do
        post_call_data_record(:queue_only => true)
      end

      it "should queue a job to Resque for saving the CDR and return immediately" do
        CallDataRecordCreator.should have_queued(sample_cdr.body)
      end

      context "when the job is run" do
        let(:new_cdr) { CallDataRecord.find_by_uuid(sample_cdr.uuid) }

        def perform_background_job
          super(:call_data_record_creator_queue)
        end

        it "should create the CDR with the correct fields" do
          if asserted_cdr_type.present?
            perform_background_job
            new_cdr.should be_present
            new_cdr.should be_valid
            asserted_cdr_type.last.should == new_cdr
          else
            expect { perform_background_job }.to raise_error(ActiveRecord::RecordInvalid)
            new_cdr.should be_nil
          end
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
