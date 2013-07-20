class AddActivatedAtToUsers < ActiveRecord::Migration
  def change
    add_column :users, :activated_at, :timestamp
  end
end
