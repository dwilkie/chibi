class MoMessageObserver < ActiveRecord::Observer
  def after_create(mo_message)
    # reply to the message
  end
end

