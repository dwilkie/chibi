class RemoveUnusedIndexes < ActiveRecord::Migration
  def change
    remove_index :call_data_records, :bridge_uuid
    remove_index :call_data_records, :direction
    remove_index :call_data_records, :inbound_cdr_id
    remove_index :call_data_records, :from
    remove_index :phone_calls, :state
    remove_index :users, :looking_for
    remove_index :users, :gender
    remove_index :chats, :user_id
    remove_index :messages, :state
  end
end
