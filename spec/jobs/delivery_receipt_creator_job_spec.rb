require 'rails_helper'

describe DeliveryReceiptCreatorJob do
  let(:options) { ActionController::Parameters.new("token" => "token", "state" => "state") }
  subject { described_class.new(options) }

  it "should be serializeable" do
    expect(subject.serialize["arguments"].first).to eq(options)
  end

  describe "#queue_name" do
    it { expect(subject.queue_name).to eq("high") }
  end

  describe "#perform(params)" do
    let(:reply) { double(Reply) }

    before do
      allow(reply).to receive(:delivery_status_updated_by_nuntium!)
      allow(Reply).to receive(:find_by_token).and_return(reply)
    end

    it "should update the delivery state of the reply" do
      expect(Reply).to receive(:find_by_token).with("token")
      expect(reply).to receive(:delivery_status_updated_by_nuntium!).with(options[:state])
      subject.perform(options)
    end
  end
end
