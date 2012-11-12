class CreateDeliveryRecipts < ActiveRecord::Migration
  def change
    create_table :delivery_receipts do |t|
      t.string     :state
      t.string     :channel
      t.string     :token
      t.references :reply
      t.timestamps
    end

    add_index :delivery_receipts, :reply_id
    add_index :delivery_receipts, [:state, :token], :unique => true
    add_index :delivery_receipts, :token
  end
end
