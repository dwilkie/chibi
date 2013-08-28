class AddOperatorToUser < ActiveRecord::Migration
  def change
    add_column :users, :operator_name, :string
    add_index :users, :operator_name
  end
end
