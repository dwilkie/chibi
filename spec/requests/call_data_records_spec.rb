require 'spec_helper'

describe "Call Data Records" do
  include AuthenticationHelpers
  include ResqueHelpers

  let(:new_cdr) { CallDataRecord.last }
  let(:sample_cdr) { build(:call_data_record) }

  def post_call_data_record(options = {})
    # populates the sample cdr's fields
    sample_cdr.valid?

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
    before do
      post_call_data_record(:queue_only => true)
    end

    it "should queue a job to Resque for saving the CDR and return immediately" do
      CallDataRecordCreator.should have_queued(sample_cdr.body)
    end

    context "when the job is run" do
      before do
        perform_background_job(:call_data_record_creator_queue)
      end

      it "should create the CDR with the correct fields" do
        new_cdr.body.should == sample_cdr.body
        new_cdr.uuid.should == sample_cdr.uuid
        new_cdr.bill_sec.should == sample_cdr.bill_sec
        new_cdr.duration.should == sample_cdr.duration
        new_cdr.rfc2822_date.should == sample_cdr.rfc2822_date
        new_cdr.phone_call.should be_present
      end
    end
  end
end
