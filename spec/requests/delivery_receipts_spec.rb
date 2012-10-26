require 'spec_helper'

describe "Delivery Receipts" do
  include AuthenticationHelpers

  let(:message) { create(:message_with_guid) }
  let(:new_delivery_receipt) { DeliveryReceipt.last }

  def post_delivery_receipt(options = {})
    post delivery_receipts_path, {
      :state => options[:state] || "delivered",
      :guid => options[:guid] || options[:message].try(:guid),
      :suggested_channel => options[:suggested_channel] || "smart",
      :country => options[:country] || "KH",
      :channel => options[:channel] || "smart"
    },
    authentication_params(:delivery_receipt)

    response.status.should be(options[:response] || 201)
  end

  describe "POST /delivery_receipts" do
    context "when a delivery receipt is received" do
      context "for a previously sent message" do
        before do
          post_delivery_receipt(:message => message)
        end

        it "should link the delivery receipt with the message" do
          message.delivery_receipts.should == [new_delivery_receipt]
        end
      end
    end
  end
end
