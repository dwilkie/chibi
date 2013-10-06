require 'spec_helper'

describe ChatReactivator do
  context "@queue" do
    it "should == :chat_reactivator_queue" do
      subject.class.instance_variable_get(:@queue).should == :chat_reactivator_queue
    end
  end

  describe ".perform(chat_id)" do
    let(:find_stub) { Chat.stub(:find) }
    let(:chat) { mock_model(Chat) }

    before do
      chat.stub(:reinvigorate!)
      find_stub.and_return(chat)
    end

    it "should tell the chat to reinvigorate itself" do
      chat.should_receive(:reinvigorate!)
      subject.class.perform(1)
    end

    it_should_behave_like "rescheduling SIGTERM exceptions" do
      let(:args) { [1] }
    end
  end
end
