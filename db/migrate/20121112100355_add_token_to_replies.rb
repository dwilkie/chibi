class AddTokenToReplies < ActiveRecord::Migration
  def change
    add_column :replies, :token, :string
    add_index :replies, :token, :unique => true
  end
end
