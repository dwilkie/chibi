class AddActiveToMsisdnDiscoveryRuns < ActiveRecord::Migration
  def change
    add_column(:msisdn_discovery_runs, :active, :boolean, :default => true, :null => false)
  end
end
