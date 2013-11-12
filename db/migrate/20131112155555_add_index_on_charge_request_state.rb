class AddIndexOnChargeRequestState < ActiveRecord::Migration
  def change
    add_index :charge_requests, [:updated_at, :state]
  end
end
