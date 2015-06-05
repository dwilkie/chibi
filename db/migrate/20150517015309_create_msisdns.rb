class CreateMsisdns < ActiveRecord::Migration
  def change
    create_table :msisdns do |t|
      t.string     :mobile_number,              :null => false
      t.boolean    :active,                     :null => false, :default => false
      t.timestamps                              :null => false
    end

    add_index :msisdns, :mobile_number, :unique => true
  end
end
