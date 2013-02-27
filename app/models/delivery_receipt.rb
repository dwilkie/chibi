class DeliveryReceipt < ActiveRecord::Base
  belongs_to :reply
  validates :reply, :token, :state, :presence => true
  validates :token, :uniqueness => {:scope => :state}

  before_validation :link_to_reply

  def self.set_reply_states!
    # mark replies as 'queued_for_smsc_delivery' if delivered_at IS NOT NULL and delivery state = 'pending_delivery'

    Reply.update_all({:state => :queued_for_smsc_delivery}, "delivered_at IS NOT NULL AND state = 'pending_delivery'")

    # mark replies as 'confirmed' if the last delivery receipt received was 'confirmed'
    # and the reply state is 'queued_for_smsc_delivery'
    connection.execute(
      %Q{UPDATE "replies" SET "state" = 'confirmed' FROM (SELECT DISTINCT ON (delivery_receipts.reply_id) delivery_receipts.reply_id, delivery_receipts.state FROM delivery_receipts ORDER by reply_id, delivery_receipts.id DESC) foo where foo.state = 'confirmed' AND replies.id = foo.reply_id AND replies.state = 'queued_for_smsc_delivery';}
    )

    # mark replies as 'rejected' if the first delivery receipt received was 'failed'
    # and the reply state is 'queued_for_smsc_delivery'
    connection.execute(
      %Q{UPDATE "replies" SET "state" = 'rejected' FROM (SELECT DISTINCT ON (delivery_receipts.reply_id) delivery_receipts.reply_id, delivery_receipts.state FROM delivery_receipts ORDER by reply_id, delivery_receipts.id) foo where foo.state = 'failed' AND replies.id = foo.reply_id AND replies.state = 'queued_for_smsc_delivery';}
    )

    # mark replies as 'failed' if the last delivery receipt received was 'failed'
    # and the reply state is 'queued_for_smsc_delivery'
    connection.execute(
      %Q{UPDATE "replies" SET "state" = 'failed' FROM (SELECT DISTINCT ON (delivery_receipts.reply_id) delivery_receipts.reply_id, delivery_receipts.state FROM delivery_receipts ORDER by reply_id, delivery_receipts.id DESC) foo where foo.state = 'failed' AND replies.id = foo.reply_id AND replies.state = 'queued_for_smsc_delivery';}
    )

    # mark replies as 'delivered_by_smsc' if the first delivery receipt received was 'delivered'
    # and the reply state is 'queued_for_smsc_delivery'
    connection.execute(
      %Q{UPDATE "replies" SET "state" = 'delivered_by_smsc' FROM (SELECT DISTINCT ON (delivery_receipts.reply_id) delivery_receipts.reply_id, delivery_receipts.state FROM delivery_receipts ORDER by reply_id, delivery_receipts.id) foo where foo.state = 'delivered' AND replies.id = foo.reply_id AND replies.state = 'queued_for_smsc_delivery';}
    )

    # mark replies as 'failed' if the last delivery receipt received was 'delivered'
    # and the reply state is 'rejected'
    # this fixes those delivery receipts that were received in the wrong order
    # and those that were incorrectly marked as rejected
    connection.execute(
      %Q{UPDATE "replies" SET "state" = 'failed' FROM (SELECT DISTINCT ON (delivery_receipts.reply_id) delivery_receipts.reply_id, delivery_receipts.state FROM delivery_receipts ORDER by reply_id, delivery_receipts.id DESC) foo where foo.state = 'delivered' AND replies.id = foo.reply_id AND replies.state = 'rejected';}
    )
  end

  private

  def link_to_reply
    self.reply = Reply.find_by_token(token)
  end
end
