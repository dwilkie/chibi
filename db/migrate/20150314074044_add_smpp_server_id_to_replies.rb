class AddSmppServerIdToReplies < ActiveRecord::Migration
  def change
    add_column(:replies, :smpp_server_id, :string)
  end
end
