class RemoveLowScanHighWriteIndexes < ActiveRecord::Migration
  def change
    remove_index(:replies, :column => :state)
    remove_index(:chats, :column => :updated_at)
    remove_index(:chats, :column => [:starter_type, :starter_id])
    remove_index(:chats, :column => :friend_id)
    remove_index(:charge_requests, :column => ["updated_at", "state"])
    remove_index(:users, :column => :latest_charge_request_id)
    remove_index(:users, :column => :operator_name)
    remove_index(:users, :column => :state)
    remove_index(:users, :column => :active_chat_id)
  end
end
