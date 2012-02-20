class RemovePriorityFromReplies < ActiveRecord::Migration
  def up
    remove_column :replies, :priority
  end

  def down
    add_column :replies, :priority, :integer
    add_index  :replies, :priority
  end
end
