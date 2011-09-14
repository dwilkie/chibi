class MtMessageObserver < ActiveRecord::Observer
  def after_create(mt_message)
    Nuntium.send_ao mt_message.attributes.slice('body').merge(:to => mt_message.user.mobile_number)
  end
end

