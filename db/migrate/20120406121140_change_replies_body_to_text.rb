class ChangeRepliesBodyToText < ActiveRecord::Migration
  def up
    change_column :replies, :body, :text
  end

  def down
    change_column :replies, :body, :string
  end
end
