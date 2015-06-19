class AddSmscPriorityToReplies < ActiveRecord::Migration
  def change
    add_column :replies, :smsc_priority, :integer, :null => false, :default => -100
    change_column :replies, :smsc_priority, :integer, :null => false, :default => 0
  end
end
