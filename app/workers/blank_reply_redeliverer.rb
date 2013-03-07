class BlankReplyRedeliverer
  @queue = :blank_reply_redeliverer_queue

  def self.perform(reply_id)
    reply = Reply.find(reply_id)
    reply.redeliver_blank!
  end
end
