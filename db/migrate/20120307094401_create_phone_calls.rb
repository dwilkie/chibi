class CreatePhoneCalls < ActiveRecord::Migration
  def change
    create_table :phone_calls do |t|
      t.integer    :sid
      t.integer    :digits
      t.string     :from
      t.references :user
      t.references :chat
      t.timestamps
    end

    add_index :phone_calls, :user_id
    add_index :phone_calls, :chat_id
    add_index :phone_calls, :sid
  end
end
