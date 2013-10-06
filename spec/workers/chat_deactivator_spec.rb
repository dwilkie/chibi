require 'spec_helper'

describe ChatDeactivator do
  context "@queue" do
    it "should == :chat_deactivator_queue" do
      subject.class.instance_variable_get(:@queue).should == :chat_deactivator_queue
    end
  end

  describe ".perform(chat_id, options = {})" do
    let(:chat) { mock_model(Chat) }
    let(:find_stub) { Chat.stub(:find) }

    before do
      chat.stub(:deactivate!)
      find_stub.and_return(chat)
    end

    it "should tell the chat to deactivate itself" do
      chat.should_receive(:deactivate!) do |options|
        options["some"].should == :options
        options[:some].should == :options
        options.should be_a(HashWithIndifferentAccess)
      end
      subject.class.perform(1, :some => :options)
    end

    it_should_behave_like "rescheduling SIGTERM exceptions" do
      let(:args) { [1, {}] }
    end
  end
end
