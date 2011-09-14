class MoMessageObserver < ActiveRecord::Observer
  def after_create(mo_message)
    mo_message.process!
  end
end

