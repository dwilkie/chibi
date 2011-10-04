class CreateChats < ActiveRecord::Migration
  def change
    create_table :chats do |t|
      t.references :user
      t.references :friend
      t.timestamps
    end

    add_index :chats, [:user_id, :friend_id], :unique => true
  end
end

