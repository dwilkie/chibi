class MoMessageObserver < ActiveRecord::Observer
  observe :mo_message

  def after_create(mo_message)
    MtMessage.create mo_message.process!
  end
end

