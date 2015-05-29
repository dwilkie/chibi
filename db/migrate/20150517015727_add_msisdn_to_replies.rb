class AddMsisdnToReplies < ActiveRecord::Migration
  def change
    add_reference :replies, :msisdn, :foreign_key => true
  end
end
