class CreatePhoneCalls < ActiveRecord::Migration
  def change
    create_table :phone_calls do |t|
      t.string     :sid
      t.string     :from
      t.string     :state
      t.references :user
      t.references :chat
      t.timestamps
    end

    add_index :phone_calls, :user_id
    add_index :phone_calls, :chat_id
    add_index :phone_calls, :state
    add_index :phone_calls, :sid, :unique => true
  end
end
