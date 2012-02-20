class RemoveReadFromReplies < ActiveRecord::Migration
  def up
    remove_column :replies, :read
  end

  def down
    add_column :replies, :read, :boolean, :default => false
    add_index  :replies, :read
  end
end
