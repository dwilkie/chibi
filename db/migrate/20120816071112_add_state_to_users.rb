class AddStateToUsers < ActiveRecord::Migration
  def up
    add_column :users, :state, :string, :null => false, :default => "online"
    add_index :users, :state

    User.where(:online => false).find_each do |user|
      user.update_column(:state, "offline")
    end

    remove_column :users, :online
  end

  def down
    add_column :users, :online, :string, :null => false, :default => true

    User.where(:state => "offline").find_each do |user|
      user.update_column(:online, false)
    end

    remove_column :users, :state
  end
end
