class RemoveUniquePhoneCallIdIndexOnCdr < ActiveRecord::Migration
  def up
    remove_index :call_data_records, :phone_call_id
    add_index :call_data_records, [:phone_call_id, :type], :unique => true
  end

  def down
    remove_index :call_data_records, [:phone_call_id, :type]
    add_index :call_data_records, :phone_call_id, :unique => true
  end
end
