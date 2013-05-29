class AddFieldsForStiToCallDataRecords < ActiveRecord::Migration
  def change
    add_column :call_data_records, :type, :string
    add_column :call_data_records, :inbound_cdr_id, :integer
    add_column :call_data_records, :bridge_uuid, :string
    add_column :call_data_records, :from, :string

    add_index :call_data_records, :direction
    add_index :call_data_records, :inbound_cdr_id
    add_index :call_data_records, :bridge_uuid
    add_index :call_data_records, :from
  end
end
