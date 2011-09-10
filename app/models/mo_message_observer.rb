class MoMessageObserver < ActiveRecord::Observer
  def after_create(mo_message)
    MtMessage.create :to => mo_message.from, :body => "you send: #{mo_message.body}"
  end
end

