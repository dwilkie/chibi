class CreateMsisdnDiscoveryRuns < ActiveRecord::Migration
  def change
    create_table :msisdn_discovery_runs do |t|
      t.string :prefix,                 :null => false
      t.integer :subscriber_number_min, :null => false
      t.integer :subscriber_number_max, :null => false
      t.string :operator,               :null => false
      t.string :country_code,           :null => false
      t.timestamps                      :null => false
    end
  end
end
