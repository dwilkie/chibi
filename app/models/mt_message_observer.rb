class MtMessageObserver < ActiveModel::Observer
  def after_create(mt_message)
    Nuntium.send_ao mt_message.attributes.slice('to', 'body')
  end
end

