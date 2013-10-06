require 'spec_helper'

describe MessageProcessor do
  context "@queue" do
    it "should == :message_processor_queue" do
      subject.class.instance_variable_get(:@queue).should == :message_processor_queue
    end
  end

  describe ".perform(message_id)" do
    let(:message) { mock_model(Message) }
    let(:find_stub) { Message.stub(:find) }

    before do
      message.stub(:process!)
      find_stub.and_return(message)
    end

    it "should tell the message to process itself" do
      message.should_receive(:process!)
      subject.class.perform(1)
    end

    it_should_behave_like "rescheduling SIGTERM exceptions" do
      let(:args) { [1] }
    end
  end
end
