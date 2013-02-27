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

  describe ".set_reply_states!" do
    before do
      create_list(:reply, 5, :delivered)
      create_list(:reply, 10, :delivered, :confirmed)
      create_list(:delivery_receipt, 10, :confirmed)
      create_list(:delivery_receipt, 15, :failed)
      create_list(:delivery_receipt, 20, :delivered)
      # simulates failed replies
      25.times do
        reply = create(:reply, :with_token, :delivered)
        create(:delivery_receipt, :delivered, :reply => reply)
        create(:delivery_receipt, :failed, :reply => reply)
      end
      # simulates a failed reply wrongly marked as rejected
      3.times do
        reply = create(:reply, :with_token, :delivered, :rejected)
        create(:delivery_receipt, :delivered, :reply => reply)
      end
      # simulates receiving a failed delivery receipt in the wrong order
      2.times do
        reply = create(:reply, :with_token, :delivered, :rejected)
        create(:delivery_receipt, :failed, :reply => reply)
        create(:delivery_receipt, :delivered, :reply => reply)
      end
    end

    # mark replies as 'failed' if the first delivery receipt received was 'delivered'
    # and the reply state is 'rejected'

    it "should mark the replies with the correct state" do
      timing = Benchmark.measure { subject.class.set_reply_states! }
      Reply.where(:state => :queued_for_smsc_delivery).count.should == 5
      Reply.where(:state => :confirmed).count.should == 20
      Reply.where(:state => :rejected).count.should == 15
      Reply.where(:state => :delivered_by_smsc).count.should == 20
      Reply.where(:state => :failed).count.should == 30
    end
  end
end
