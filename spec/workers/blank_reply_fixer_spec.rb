require 'spec_helper'

describe BlankReplyFixer do

  context "@queue" do
    it "should == :blank_reply_fixer_queue" do
      subject.class.instance_variable_get(:@queue).should == :blank_reply_fixer_queue
    end
  end

  describe ".perform" do
    let(:reply) { mock_model(Reply) }

    before do
      reply.stub(:fix_blank!)
      Reply.stub(:find).and_return(reply)
    end

    it "should fix the blank reply and mark it as undelivered" do
      reply.should_receive(:fix_blank!)
      subject.class.perform(1)
    end
  end
end
