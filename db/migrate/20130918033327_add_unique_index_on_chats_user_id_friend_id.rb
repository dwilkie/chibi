class AddUniqueIndexOnChatsUserIdFriendId < ActiveRecord::Migration
  def change
    add_index :chats, [:user_id, :friend_id], :unique => true
  end
end
