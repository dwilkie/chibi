class AddCdrDataToCallDataRecords < ActiveRecord::Migration
  def change
    add_column :call_data_records, :cdr_data, :string
  end
end
