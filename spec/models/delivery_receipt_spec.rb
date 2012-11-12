require 'spec_helper'

describe DeliveryReceipt do
  let(:message) { create(:message_with_guid) }
  let(:new_delivery_receipt) { build(:delivery_receipt, :message => message) }
  let(:delivery_receipt) { create(:delivery_receipt, :message => message) }

  describe "factory" do
    it "should be valid" do
      new_delivery_receipt.should be_valid
    end
  end

  it "should not be valid without a guid" do
    new_delivery_receipt.guid = nil
    new_delivery_receipt.should_not be_valid
  end

  it "should not be valid without a state" do
    new_delivery_receipt.state = nil
    new_delivery_receipt.should_not be_valid
  end

  it "should not be valid without an associated message" do
    new_delivery_receipt.message = nil
    new_delivery_receipt.guid = "unknown guid"
    new_delivery_receipt.should_not be_valid
  end

  it "should not be valid with a duplicate guid and state" do
    delivery_receipt.dup.should_not be_valid
  end

  describe "callbacks" do
    describe "before validation" do
      it "should link the message" do
        new_delivery_receipt.message = nil
        new_delivery_receipt.message.should be_nil
        new_delivery_receipt.valid?
        new_delivery_receipt.message.should == message
      end
    end
  end
end
