class DeliveryReceiptsController < ApplicationController
  protect_from_forgery :except => :create

  before_filter :authenticate_delivery_receipt

  def create
    delivery_receipt = DeliveryReceipt.new(params.slice(:channel, :token, :state))
    status = delivery_receipt.save ? :created : :bad_request
    puts delivery_receipt.errors.full_messages
    render(:nothing => true, :status => status)
  end

  private

  def authenticate_delivery_receipt
    authenticate(:delivery_receipt)
  end
end