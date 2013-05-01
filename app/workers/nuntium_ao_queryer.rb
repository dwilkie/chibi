class NuntiumAoQueryer
  @queue = :nuntium_ao_queryer_queue

  def self.perform(reply_id)
    Reply.find(reply_id).query_nuntium_ao!
  rescue Resque::TermException
    Resque.enqueue(self, reply_id)
  end
end
