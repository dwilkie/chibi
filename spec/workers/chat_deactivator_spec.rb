require 'spec_helper'

describe ChatDeactivator do

  context "@queue" do
    it "should == :chat_deactivator_queue" do
      subject.class.instance_variable_get(:@queue).should == :chat_deactivator_queue
    end
  end

  describe ".perform" do
    let(:chat) { mock_model(Chat) }

    before do
      chat.stub(:deactivate!)
      Chat.stub(:find).and_return(chat)
    end

    it "should tell the chat to deactivate itself" do
      chat.should_receive(:deactivate!) do |options|
        options["some"].should == :options
        options[:some].should == :options
        options.should be_a(HashWithIndifferentAccess)
      end
      subject.class.perform(1, :some => :options)
    end

    it_should_behave_like "rescheduling redis max client errors"
  end
end
