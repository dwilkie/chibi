require 'spec_helper'

describe NuntiumAoQueryer do
  context "@queue" do
    it "should == :nuntium_ao_queryer_queue" do
      subject.class.instance_variable_get(:@queue).should == :nuntium_ao_queryer_queue
    end
  end

  describe ".perform(reply_id)" do
    let(:reply) { mock_model(Reply) }
    let(:find_stub) { Reply.stub(:find) }

    before do
      reply.stub(:query_nuntium_ao!)
      find_stub.and_return(reply)
    end

    it "should query the ao for the reply from Nuntium" do
      reply.should_receive(:query_nuntium_ao!)
      subject.class.perform(1)
    end

    it_should_behave_like "rescheduling SIGTERM exceptions" do
      let(:args) { [1] }
      let(:error_stub) { find_stub }
    end
  end
end
