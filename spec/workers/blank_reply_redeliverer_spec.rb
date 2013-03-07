require 'spec_helper'

describe BlankReplyRedeliverer do

  context "@queue" do
    it "should == :blank_reply_redeliverer_queue" do
      subject.class.instance_variable_get(:@queue).should == :blank_reply_redeliverer_queue
    end
  end

  describe ".perform" do
    let(:reply) { mock_model(Reply) }

    before do
      reply.stub(:redeliver_blank!)
      Reply.stub(:find).and_return(reply)
    end

    it "should redelivery the reply based off of the intended message in the chat" do
      reply.should_receive(:redeliver_blank!)
      subject.class.perform(1)
    end
  end
end
