class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :mobile_number
      t.string :name
      t.string :username
      t.date   :date_of_birth
      t.string :gender, :limit => 1
      t.string :location
      t.string :looking_for, :limit => 1
      t.string  :state, :default => 'newbie'
      t.references :active_chat
      t.timestamps
    end

    add_index :users, :username, :unique => true
    add_index :users, :mobile_number, :unique => true
    add_index :users, :active_chat_id

  end
end

