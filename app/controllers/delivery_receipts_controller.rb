class DeliveryReceiptsController < ApplicationController
  protect_from_forgery :except => :create

  before_filter :authenticate_delivery_receipt

  def create
    DeliveryReceiptCreatorJob.perform_later(params)
    render(:nothing => true, :status => :created)
  end

  private

  def authenticate_delivery_receipt
    authenticate(:delivery_receipt)
  end
end
