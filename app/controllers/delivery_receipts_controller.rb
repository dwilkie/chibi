class DeliveryReceiptsController < ApplicationController
  protect_from_forgery :except => :create

  before_filter :authenticate_delivery_receipt

  def create
    reply = Reply.find_by_token!(params[:token])
    puts "updating delivery state for delivery receipts..."
    puts "delivery state was: #{reply.state}"
    puts reply.update_delivery_state(params[:state])
    puts "delivery state is now: #{reply.state}"
    render(:nothing => true, :status => :created)
  end

  private

  def authenticate_delivery_receipt
    authenticate(:delivery_receipt)
  end
end
