class RemoveActivatedAtFromUsers < ActiveRecord::Migration
  def change
    remove_column(:users, :activated_at)
  end
end
