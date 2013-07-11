class AddLastInteractedAtToUsers < ActiveRecord::Migration
  def change
    add_column :users, :last_interacted_at, :timestamp
    add_column :users, :last_contacted_at,  :timestamp
  end
end
