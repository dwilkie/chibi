require 'spec_helper'

describe ChatReactivator do

  context "@queue" do
    it "should == :chat_reactivator_queue" do
      subject.class.instance_variable_get(:@queue).should == :chat_reactivator_queue
    end
  end

  describe ".perform" do
    context "with no chat id" do
      before do
        Chat.stub(:reactivate_stagnant!)
      end

      it "should reactivate all stagnant chats" do
        Chat.should_receive(:reactivate_stagnant!)
        subject.class.perform
      end
    end

    context "with a chat id" do
      let(:chat) { mock_model(Chat) }

      before do
        chat.stub(:reactivate!)
        Chat.stub(:find).and_return(chat)
      end

      it "should tell the chat to reactivate itself" do
        chat.should_receive(:reactivate!)
        subject.class.perform(1)
      end
    end
  end
end
