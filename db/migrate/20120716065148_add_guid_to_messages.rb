class AddGuidToMessages < ActiveRecord::Migration
  def change
    add_column :messages, :guid, :string
  end
end
