require 'spec_helper'

describe CdrUploader do

  describe "@queue" do
    it "should == :cdr_uploader_queue" do
      subject.class.instance_variable_get(:@queue).should == :cdr_uploader_queue
    end
  end

  describe ".perform(cdr_id)" do
    let(:cdr) { mock_model(CallDataRecord) }
    let(:find_stub) { CallDataRecord.stub(:find) }
    let(:id) { 1 }
    let(:body) { "body" }

    before do
      cdr.stub(:save!)
      cdr.stub(:read_attribute).and_return(body)
      cdr.stub(:set_cdr_data)
      find_stub.and_return(cdr)
    end

    it "should tell the cdr to upload itself" do
      CallDataRecord.should_receive(:find).with(id)
      cdr.should_receive(:save!)
      cdr.should_receive(:read_attribute).with(:body)
      cdr.should_receive(:set_cdr_data).with(body)
      subject.class.perform(id)
    end

    it_should_behave_like "rescheduling SIGTERM exceptions" do
      let(:args) { [id] }
    end
  end
end
