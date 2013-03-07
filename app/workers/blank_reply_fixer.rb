class BlankReplyFixer
  @queue = :blank_reply_fixer_queue

  def self.perform(reply_id)
    reply = Reply.find(reply_id)
    reply.fix_blank!
  end
end
