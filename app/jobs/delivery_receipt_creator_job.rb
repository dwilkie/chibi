class DeliveryReceiptCreatorJob < ActiveJob::Base
  queue_as :high

  def perform(params)
    if reply = Reply.find_by_token(params[:token])
      reply.delivery_status_updated_by_nuntium!(params[:state])
    end
  end
end
