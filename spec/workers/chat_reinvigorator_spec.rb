require 'spec_helper'

describe ChatReinvigorator do
  context "@queue" do
    it "should == :chat_reinvigorator_queue" do
      subject.class.instance_variable_get(:@queue).should == :chat_reinvigorator_queue
    end
  end

  describe ".perform" do
    let(:job_stub) { Chat.stub(:reinvigorate!) }

    before do
      job_stub
    end

    it "should reactivate all stagnant chats" do
      Chat.should_receive(:reinvigorate!)
      subject.class.perform
    end

    it_should_behave_like "rescheduling SIGTERM exceptions" do
      let(:args) { [] }
    end
  end
end
