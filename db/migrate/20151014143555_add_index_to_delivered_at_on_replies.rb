class AddIndexToDeliveredAtOnReplies < ActiveRecord::Migration
  def change
    add_index(:replies, :delivered_at)
  end
end
