class MoMessageObserver < ActiveModel::Observer
  def after_create(mo_message)
    logger.error 'creating an mt_message'
    MtMessage.create :to => mo_message.from, :body => "you send: #{mo_message.body}"
  end
end

