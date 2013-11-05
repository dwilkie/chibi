class AddLatestChargeRequestToUsers < ActiveRecord::Migration
  def change
    add_column :users, :latest_charge_request_id, :integer
    add_index :users, :latest_charge_request_id
  end
end
