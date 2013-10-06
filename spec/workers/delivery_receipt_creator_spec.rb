require 'spec_helper'

describe DeliveryReceiptCreator do
  context "@queue" do
    it "should == :delivery_receipt_creator_queue" do
      subject.class.instance_variable_get(:@queue).should == :delivery_receipt_creator_queue
    end
  end

  describe ".perform(params)" do
    let(:reply) { mock_model(Reply) }
    let(:find_stub) { Reply.stub(:find_by_token) }
    let(:params) { { :token => :token, :state => :state} }

    before do
      reply.stub(:update_delivery_state)
      find_stub.and_return(reply)
    end

    it "should update the delivery state of the reply" do
      Reply.should_receive(:find_by_token).with(:token)
      reply.should_receive(:update_delivery_state) do |options|
        options[:state].should == :state
        options[:force].should be_true
      end
      subject.class.perform(params)
    end

    it_should_behave_like "rescheduling SIGTERM exceptions" do
      let(:args) { [params.with_indifferent_access] }
    end
  end
end
