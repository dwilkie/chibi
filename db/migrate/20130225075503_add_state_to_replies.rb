class AddStateToReplies < ActiveRecord::Migration
  def change
    add_column :replies, :state, :string, :null => false, :default => "pending_delivery"
    add_index  :replies, :state
  end
end
