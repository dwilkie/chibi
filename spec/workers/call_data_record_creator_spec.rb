require 'spec_helper'

describe CallDataRecordCreator do
  context "@queue" do
    it "should == :call_data_record_creator_queue" do
      subject.class.instance_variable_get(:@queue).should == :call_data_record_creator_queue
    end
  end

  describe ".perform(body)" do
    let(:create_stub) { CallDataRecord.stub(:create!) }
    let(:body) { "foo" }

    before do
      create_stub
    end

    it "should create the CDR with a bang!" do
      CallDataRecord.should_receive(:create!).with(:body => body)
      subject.class.perform(body)
    end

    it_should_behave_like "rescheduling SIGTERM exceptions" do
      let(:args) { [body] }
      let(:error_stub) { create_stub }
    end
  end
end
