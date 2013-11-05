class CreateChargeRequests < ActiveRecord::Migration
  def change
    create_table :charge_requests do |t|
      t.string     :result
      t.string     :state
      t.string     :operator
      t.boolean    :notify_requester, :default => false, :null => false
      t.references :requester, :polymorphic => true
      t.references :user
      t.timestamps
    end

    add_index :charge_requests, [:requester_type, :requester_id]
    add_index :charge_requests, :user_id
  end
end
