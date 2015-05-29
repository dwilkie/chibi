class CreateMsisdns < ActiveRecord::Migration
  def change
    create_table :msisdns do |t|
      t.string :mobile_number, :null => false
      t.string :operator, :null => false
      t.string :country_code, :null => false
      t.string :state, :null => false
      t.datetime :last_checked_at
      t.timestamps :null => false
    end

    add_index :msisdns, :mobile_number, :unique => true
  end
end
