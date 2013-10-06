require 'spec_helper'

describe Dialer do
  context "@queue" do
    it "should == :dialer_queue" do
      subject.class.instance_variable_get(:@queue).should == :dialer_queue
    end
  end

  describe ".perform(missed_call_id)" do
    let(:missed_call) { mock_model(MissedCall) }
    let(:find_stub) { MissedCall.stub(:find) }

    before do
      missed_call.stub(:return_call!)
      find_stub.and_return(missed_call)
    end

    it "should return the call" do
      missed_call.should_receive(:return_call!)
      subject.class.perform(1)
    end

    it_should_behave_like "rescheduling SIGTERM exceptions" do
      let(:args) { [1] }
    end
  end
end
