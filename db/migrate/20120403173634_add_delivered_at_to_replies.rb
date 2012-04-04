class AddDeliveredAtToReplies < ActiveRecord::Migration
  def change
    add_column :replies, :delivered_at, :timestamp
  end
end
