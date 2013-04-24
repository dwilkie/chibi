class ChangeDefaultStateForMessages < ActiveRecord::Migration
  def up
    change_column :messages, :state, :string, :default => "received"
  end

  def down
    change_column :messages, :state, :string, :default => "processed"
  end
end
