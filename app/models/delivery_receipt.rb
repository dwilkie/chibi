class DeliveryReceipt < ActiveRecord::Base
  belongs_to :reply
  validates :reply, :token, :state, :presence => true
  validates :token, :uniqueness => {:scope => :state}

  before_validation :link_to_reply

  def self.set_reply_states!
    Reply.update_all({:state => :queued_for_smsc_delivery}, "delivered_at IS NOT NULL AND state = 'pending_delivery'")

    connection.execute(
      %Q{UPDATE "replies" SET "state" = 'confirmed' FROM (SELECT DISTINCT ON (delivery_receipts.reply_id) delivery_receipts.reply_id, delivery_receipts.state FROM delivery_receipts INNER JOIN replies ON delivery_receipts.reply_id = replies.id WHERE replies.state = 'queued_for_smsc_delivery' ORDER by reply_id, delivery_receipts.id DESC) foo where foo.state = 'confirmed' AND replies.id = foo.reply_id;}
    )

    connection.execute(
      %Q{UPDATE "replies" SET "state" = 'rejected' FROM (SELECT DISTINCT ON (delivery_receipts.reply_id) delivery_receipts.reply_id, delivery_receipts.state FROM delivery_receipts INNER JOIN replies ON delivery_receipts.reply_id = replies.id WHERE replies.state = 'queued_for_smsc_delivery' ORDER by reply_id, delivery_receipts.id) foo where foo.state = 'failed' AND replies.id = foo.reply_id;}
    )

    connection.execute(
      %Q{UPDATE "replies" SET "state" = 'failed' FROM (SELECT DISTINCT ON (delivery_receipts.reply_id) delivery_receipts.reply_id, delivery_receipts.state FROM delivery_receipts INNER JOIN replies ON delivery_receipts.reply_id = replies.id WHERE replies.state = 'queued_for_smsc_delivery' ORDER by reply_id, delivery_receipts.id DESC) foo where foo.state = 'failed' AND replies.id = foo.reply_id;}
    )

    connection.execute(
      %Q{UPDATE "replies" SET "state" = 'delivered_by_smsc' FROM (SELECT DISTINCT ON (delivery_receipts.reply_id) delivery_receipts.reply_id, delivery_receipts.state FROM delivery_receipts INNER JOIN replies ON delivery_receipts.reply_id = replies.id WHERE replies.state = 'queued_for_smsc_delivery' ORDER by reply_id, delivery_receipts.id) foo where foo.state = 'delivered' AND replies.id = foo.reply_id;}
    )
  end

  private

  def link_to_reply
    self.reply = Reply.find_by_token(token)
  end
end
