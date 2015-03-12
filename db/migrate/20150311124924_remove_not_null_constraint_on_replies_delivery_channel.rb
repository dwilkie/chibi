class RemoveNotNullConstraintOnRepliesDeliveryChannel < ActiveRecord::Migration
  def change
    change_column(:replies, :delivery_channel, :string, :null => true, :default => nil)
  end
end
