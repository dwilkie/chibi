class ReplyStateQueryer
  @queue = :reply_state_queryer_queue

  def self.perform(reply_id)
    reply = Reply.find(reply_id)
    reply.query_state!
  end
end
