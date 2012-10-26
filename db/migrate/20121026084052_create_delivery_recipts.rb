class CreateDeliveryRecipts < ActiveRecord::Migration
  def change
    create_table :delivery_receipts do |t|
      t.string     :state
      t.string     :channel
      t.string     :guid
      t.references :message
      t.timestamps
    end

    add_index :delivery_receipts, :message_id
    add_index :delivery_receipts, [:state, :guid], :unique => true
    add_index :delivery_receipts, :guid
  end
end
