class AddSmscDeliveryStatusToReply < ActiveRecord::Migration
  def change
    add_column(:replies, :smsc_message_status, :string)
  end
end
