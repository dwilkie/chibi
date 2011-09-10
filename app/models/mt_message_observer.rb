class MtMessageObserver < ActiveRecord::Observer
  def after_create(mt_message)
    # Send the message
  end
end

