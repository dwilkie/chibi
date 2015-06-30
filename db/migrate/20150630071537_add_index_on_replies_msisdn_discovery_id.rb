class AddIndexOnRepliesMsisdnDiscoveryId < ActiveRecord::Migration
  def change
    add_index(:replies, :msisdn_discovery_id)
  end
end
