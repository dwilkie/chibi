class MtMessageObserver < ActiveRecord::Observer
  def after_create(mt_message)
    Nuntium.send_ao mt_message.attributes.silce 'to', 'body'
  end
end

