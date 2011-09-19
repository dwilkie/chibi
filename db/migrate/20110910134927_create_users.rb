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
      t.string :state, :default => 'newbie'
      t.timestamps
    end

    add_index :users, :username, :unique => true
    add_index :users, :mobile_number, :unique => true
    add_index :users, :location
    add_index :users, :looking_for
    add_index :users, :gender
    add_index :users, :date_of_birth
  end
end

