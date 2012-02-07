require 'spec_helper'

describe MessageProcessor do

  context "@queue" do
    it "should == :message_processor_queue" do
      subject.class.instance_variable_get(:@queue).should == :message_processor_queue
    end
  end

  describe ".perform" do
    let(:message) { mock_model(Message) }

    before do
      message.stub(:process!)
      Message.stub(:find).and_return(message)
    end

    it "should tell the message to process itself" do
      message.should_receive(:process!)
      subject.class.perform(1)
    end
  end
end
