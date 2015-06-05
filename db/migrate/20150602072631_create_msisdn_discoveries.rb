class CreateMsisdnDiscoveries < ActiveRecord::Migration
  def change
    create_table :msisdn_discoveries do |t|
      t.references :msisdn,                       :null => false, :foreign_key => true
      t.references :msisdn_discovery_run,         :null => false, :foreign_key => true
      t.integer    :subscriber_number,            :null => false
      t.string     :state,                        :null => false
      t.timestamps                                :null => false
    end

    add_index :msisdn_discoveries, [:msisdn_id, :msisdn_discovery_run_id], :unique => true, :name => "index_msisdn_discoveries"
  end
end
