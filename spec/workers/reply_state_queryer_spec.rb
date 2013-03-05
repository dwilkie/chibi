require 'spec_helper'

describe ReplyStateQueryer do

  context "@queue" do
    it "should == :reply_state_queryer_queue" do
      subject.class.instance_variable_get(:@queue).should == :reply_state_queryer_queue
    end
  end

  describe ".perform" do
    let(:reply) { mock_model(Reply) }

    before do
      reply.stub(:query_state!)
      Reply.stub(:find).and_return(reply)
    end

    it "should query the ao state of the reply from Nuntium" do
      reply.should_receive(:query_state!)
      subject.class.perform(1)
    end
  end
end
