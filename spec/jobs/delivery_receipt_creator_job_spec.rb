require 'spec_helper'

describe DeliveryReceiptCreatorJob do
  describe "#queue_name" do
    it { expect(subject.queue_name).to eq("delivery_receipt_creator_queue") }
  end

  describe "#perform(params)" do
    let(:reply) { double(Reply) }
    let(:params) { ActionController::Parameters.new("token" => :token, "state" => :state) }

    before do
      allow(reply).to receive(:update_delivery_state)
      allow(Reply).to receive(:find_by_token).and_return(reply)
    end

    it "should update the delivery state of the reply" do
      expect(Reply).to receive(:find_by_token).with(:token)
      expect(reply).to receive(:update_delivery_state) do |options|
        options[:state].should == :state
        options[:force].should == true
      end
      subject.perform(params)
    end
  end
end
