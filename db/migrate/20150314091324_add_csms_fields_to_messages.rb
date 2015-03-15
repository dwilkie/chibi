class AddCsmsFieldsToMessages < ActiveRecord::Migration
  def change
    add_column(:messages, :csms_reference_number, :integer, :null => false, :default => 0)
    add_column(:messages, :number_of_parts, :integer, :null => false, :default => 1)
    add_column(:messages, :awaiting_parts, :boolean, :null => false, :default => false)
  end
end
