class NuntiumAoQueryer
  @queue = :nuntium_ao_queryer_queue

  def self.perform(reply_id)
    reply = Reply.find(reply_id)
    reply.query_nuntium_ao!
  end
end
