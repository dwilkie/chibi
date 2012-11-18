class AddStateToMessages < ActiveRecord::Migration
  def up
    add_column :messages, :state, :string, :null => false, :default => "processed"
    add_index :messages, :state

    Message.update_all({:state => "processed"}, {:state => nil})
  end

  def down
    remove_column :messages, :state
  end
end
