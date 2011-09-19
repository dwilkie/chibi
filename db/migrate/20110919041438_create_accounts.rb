class CreateAccounts < ActiveRecord::Migration
  def self.up
    create_table(:accounts) do |t|
      t.string :email
      t.string :username
      t.string :password_digest
      t.timestamps
    end

    add_index :accounts, :email,                :unique => true
    add_index :accounts, :username,             :unique => true
  end

  def self.down
    drop_table :accounts
  end
end

