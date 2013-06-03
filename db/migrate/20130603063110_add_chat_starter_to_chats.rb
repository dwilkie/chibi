class AddChatStarterToChats < ActiveRecord::Migration
  def up
    change_table :chats do |t|
      t.references :starter, :polymorphic => true
    end
    add_index :chats, [:starter_type, :starter_id]
  end

  def down
    remove_column :chats, :starter_id
    remove_column :chats, :starter_type
  end
end
