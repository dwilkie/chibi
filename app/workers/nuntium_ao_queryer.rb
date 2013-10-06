class NuntiumAoQueryer
  extend RetriedJob
  @queue = :nuntium_ao_queryer_queue

  def self.perform(reply_id)
    Reply.find(reply_id).query_nuntium_ao!
  end
end
