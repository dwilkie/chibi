class RemoveUniqueIndexOnUserIdAndFriendsIdOnChats < ActiveRecord::Migration
  def change
    remove_index :chats, [:user_id, :friend_id]
    add_index :chats, [:user_id, :friend_id]
  end
end
