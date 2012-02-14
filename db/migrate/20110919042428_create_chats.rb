class CreateChats < ActiveRecord::Migration
  def change
    create_table :chats do |t|
      t.references :user
      t.references :friend
      t.timestamps
    end

    add_index :chats, :user_id
    add_index :chats, :friend_id
    add_index :chats, :updated_at
  end
end
