class CreateSubscriptions < ActiveRecord::Migration
  def change
    create_table :subscriptions do |t|
      t.references :user
      t.references :account
      t.timestamps
    end

    add_index :subscriptions, [:user_id, :account_id], :unique => true

  end
end

