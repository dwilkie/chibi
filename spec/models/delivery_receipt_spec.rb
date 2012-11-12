require 'spec_helper'

describe DeliveryReceipt do
  let(:reply) { create(:reply_with_token) }
  let(:new_delivery_receipt) { build(:delivery_receipt, :reply => reply) }
  let(:delivery_receipt) { create(:delivery_receipt, :reply => reply) }

  describe "factory" do
    it "should be valid" do
      new_delivery_receipt.should be_valid
    end
  end

  it "should not be valid without a token" do
    new_delivery_receipt.token = nil
    new_delivery_receipt.should_not be_valid
  end

  it "should not be valid without a state" do
    new_delivery_receipt.state = nil
    new_delivery_receipt.should_not be_valid
  end

  it "should not be valid without an associated reply" do
    new_delivery_receipt.reply = nil
    new_delivery_receipt.token = "unknown token"
    new_delivery_receipt.should_not be_valid
  end

  it "should not be valid with a duplicate token and state" do
    delivery_receipt.dup.should_not be_valid
  end

  describe "callbacks" do
    describe "before validation" do
      it "should link the reply" do
        new_delivery_receipt.reply = nil
        new_delivery_receipt.reply.should be_nil
        new_delivery_receipt.valid?
        new_delivery_receipt.reply.should == reply
      end
    end
  end
end
