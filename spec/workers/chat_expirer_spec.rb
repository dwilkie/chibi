require 'spec_helper'

describe ChatExpirer do

  context "@queue" do
    it "should == :chat_expirer_queue" do
      subject.class.instance_variable_get(:@queue).should == :chat_expirer_queue
    end
  end

  describe ".perform" do
    before do
      Chat.stub(:end_inactive)
    end

    it "should tell the message to process itself" do
      Chat.should_receive(:end_inactive) do |options|
        options["some"].should == :options
        options[:some].should == :options
        options.should be_a(HashWithIndifferentAccess)
      end
      subject.class.perform(:some => :options)
    end
  end
end
