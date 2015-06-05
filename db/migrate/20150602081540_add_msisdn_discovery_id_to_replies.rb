class AddMsisdnDiscoveryIdToReplies < ActiveRecord::Migration
  def change
    add_reference :replies, :msisdn_discovery, :foreign_key => true
  end
end
