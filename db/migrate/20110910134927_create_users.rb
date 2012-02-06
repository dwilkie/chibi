class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string  :mobile_number
      t.string  :name
      t.string  :screen_name
      t.date    :date_of_birth
      t.string  :gender, :limit => 1
      t.string  :looking_for, :limit => 1
      t.boolean :online, :default => true, :null => false
      t.references :active_chat
      t.timestamps
    end

    add_index :users, :mobile_number, :unique => true
    add_index :users, :active_chat_id
    add_index :users, :online
  end
end
