require 'spec_helper'

describe ReplyStateSetter do
  context "@queue" do
    it "should == :reply_state_setter_queue" do
      subject.class.instance_variable_get(:@queue).should == :reply_state_setter_queue
    end
  end

  describe ".perform" do
    before do
      DeliveryReceipt.stub(:set_reply_states!)
    end

    it "should set the reply states for replies with delivery receipts" do
      DeliveryReceipt.should_receive(:set_reply_states!)
      subject.class.perform
    end
  end
end
