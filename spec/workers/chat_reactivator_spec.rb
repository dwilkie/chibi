require 'spec_helper'

describe ChatReactivator do

  context "@queue" do
    it "should == :chat_reactivator_queue" do
      subject.class.instance_variable_get(:@queue).should == :chat_reactivator_queue
    end
  end

  describe ".perform(chat_id = nil)" do
    let(:job_stub) { Chat.stub(:reactivate_stagnant!) }

    context "with no chat id" do
      before do
        job_stub
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

    it_should_behave_like "rescheduling SIGTERM exceptions" do
      let(:args) { [nil] }
      let(:error_stub) { job_stub }
    end
  end
end
