require 'spec_helper'

describe NuntiumAoQueryer, :focus do
  context "@queue" do
    it "should == :nuntium_ao_queryer_queue" do
      subject.class.instance_variable_get(:@queue).should == :nuntium_ao_queryer_queue
    end
  end

  describe ".perform" do
    let(:reply) { mock_model(Reply) }

    before do
      reply.stub(:query_nuntium_ao!)
      Reply.stub(:find).and_return(reply)
    end

    it "should query the ao for the reply from Nuntium" do
      reply.should_receive(:query_nuntium_ao!)
      subject.class.perform(1)
    end
  end
end
