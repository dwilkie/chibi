require 'rails_helper'

describe "Delivery Receipts" do
  include AuthenticationHelpers
  include ActiveJobHelpers

  let(:reply) { create(:reply, :nuntium_channel, :with_token, :delivered, :queued_for_smsc_delivery) }
  let(:new_delivery_receipt) { DeliveryReceipt.last }

  def post_delivery_receipt(options = {})
    post(
      delivery_receipts_path,
      {
        :state => options[:state] || "delivered",
        :token => options[:token] || options[:reply].try(:token),
        :suggested_channel => options[:suggested_channel] || "smart",
        :country => options[:country] || "KH",
        :channel => options[:channel] || "smart"
      },
      authentication_params(:delivery_receipt)
    )

    expect(response.status).to be(options[:response] || 201)
  end

  describe "POST /delivery_receipts" do
    def do_request(options = {})
      trigger_job(options) { post_delivery_receipt(options) }
    end

    context "when a delivery receipt is received" do
      context "for a previously sent reply" do
        before do
          do_request(:reply => reply)
        end

        it "should mark the reply as delivered by smsc" do
          expect(reply.reload).to be_delivered_by_smsc
        end
      end

      context "for a reply that was not sent from this app" do
        before do
          do_request
        end

        it "should ignore the delivery receipt" do
          expect(Reply.count).to eq(0)
        end
      end
    end
  end
end
