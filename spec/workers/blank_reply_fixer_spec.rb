require 'spec_helper'

describe BlankReplyFixer do
  context "@queue" do
    it "should == :blank_reply_fixer_queue" do
      subject.class.instance_variable_get(:@queue).should == :blank_reply_fixer_queue
    end
  end

  describe ".perform(reply_id)" do
    let(:reply) { mock_model(Reply) }
    let(:find_stub) { Reply.stub(:find) }

    before do
      reply.stub(:fix_blank!)
      find_stub.and_return(reply)
    end

    it "should fix the blank reply and mark it as undelivered" do
      reply.should_receive(:fix_blank!)
      subject.class.perform(1)
    end

    it_should_behave_like "rescheduling SIGTERM exceptions" do
      let(:args) { [1] }
    end
  end
end
