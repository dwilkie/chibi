class DeliveryReceiptsController < ApplicationController
  protect_from_forgery :except => :create

  before_filter :authenticate_delivery_receipt

  def create
    reply = Reply.find_by_token!(params[:token])
    puts "updating delivery state..."
    puts "current state: #{reply.state}"
    puts reply.update_delivery_state(params[:state])
    puts "new state: #{reply.state}"
    render(:nothing => true, :status => :created)
  end

  private

  def authenticate_delivery_receipt
    authenticate(:delivery_receipt)
  end
end
