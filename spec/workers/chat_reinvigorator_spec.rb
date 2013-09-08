require 'spec_helper'

describe ChatReinvigorator do
  context "@queue" do
    it "should == :chat_reinvigorator_queue" do
      subject.class.instance_variable_get(:@queue).should == :chat_reinvigorator_queue
    end
  end

  describe ".perform" do
    let(:job_stub) { Chat.stub(:reactivate_stagnant!) }

    before do
      job_stub
    end

    it "should reactivate all stagnant chats" do
      Chat.should_receive(:reactivate_stagnant!)
      subject.class.perform
    end

    it_should_behave_like "rescheduling SIGTERM exceptions" do
      let(:args) { [] }
      let(:error_stub) { job_stub }
    end
  end
end
