require 'spec_helper'

describe Dialer do

  context "@queue" do
    it "should == :dialer_queue" do
      subject.class.instance_variable_get(:@queue).should == :dialer_queue
    end
  end

  describe ".perform" do
    let(:missed_call) { mock_model(MissedCall) }

    before do
      missed_call.stub(:return_call!)
      MissedCall.stub(:find).and_return(missed_call)
    end

    it "should tell the message to process itself" do
      missed_call.should_receive(:return_call!).with("https://example.com/phone_calls.xml")
      subject.class.perform(1, "https://example.com/phone_calls.xml")
    end
  end
end
