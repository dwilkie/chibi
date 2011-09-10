class MoMessageObserver < ActiveRecord::Observer
  observe :mo_message

  def after_create(mo_message)
    m = MtMessage.create :to => mo_message.from, :body => "you send: #{mo_message.body}"
    p m
  end
end

