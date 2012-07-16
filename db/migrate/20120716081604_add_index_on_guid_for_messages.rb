class AddIndexOnGuidForMessages < ActiveRecord::Migration
  def up
    add_index :messages, :guid, :unique => true
  end

  def down
    remove_index :messages, :guid
  end
end
