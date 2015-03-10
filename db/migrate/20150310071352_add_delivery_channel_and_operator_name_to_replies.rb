class AddDeliveryChannelAndOperatorNameToReplies < ActiveRecord::Migration
  def change
    add_column(:replies, :delivery_channel, :string, :null => false, :default => "nuntium")
    add_column(:replies, :operator_name, :string)
  end
end
