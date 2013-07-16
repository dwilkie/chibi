class DeliveryReceiptCreator
  @queue = :delivery_receipt_creator_queue

  def self.perform(params)
    params = params.with_indifferent_access
    if reply = Reply.find_by_token(params[:token])
      reply.update_delivery_state(:state => params[:state], :force => true)
    end
  rescue Resque::TermException
    Resque.enqueue(self, params)
  end
end
