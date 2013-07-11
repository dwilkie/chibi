require 'spec_helper'

describe CallDataRecordCreator do
  context "@queue" do
    it "should == :call_data_record_creator_queue" do
      subject.class.instance_variable_get(:@queue).should == :call_data_record_creator_queue
    end
  end

  describe ".perform(body)" do
    let(:call_data_record) { mock_model(CallDataRecord) }
    let(:inbound_cdr) { mock_model(InboundCdr) }
    let(:save_stub) { inbound_cdr.stub(:save!) }
    let(:body) { "foo" }

    before do
      CallDataRecord.stub(:new).and_return(call_data_record)
      call_data_record.stub(:typed).and_return(inbound_cdr)
      save_stub
    end

    it "should create the CDR" do
      CallDataRecord.should_receive(:new).with(:body => body)
      inbound_cdr.should_receive(:save!)
      subject.class.perform(body)
    end

    it_should_behave_like "rescheduling SIGTERM exceptions" do
      let(:args) { [body] }
      let(:error_stub) { save_stub }
    end
  end
end
