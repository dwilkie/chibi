class DeliveryReceiptCreatorJob < ActiveJob::Base
  queue_as :high

  def perform(params)
    if reply = Reply.find_by_token(params[:token])
      reply.update_delivery_state!(params[:state])
    end
  end
end
