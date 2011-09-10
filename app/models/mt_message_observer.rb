class MtMessageObserver < ActiveModel::Observer
  def after_create(mt_message)
    logger.error 'sending mt_message...'
    Nuntium.send_ao mt_message.attributes.slice('to', 'body')
    logger.error 'done'
  end
end

