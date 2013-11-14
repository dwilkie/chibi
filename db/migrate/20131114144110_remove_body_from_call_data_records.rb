class RemoveBodyFromCallDataRecords < ActiveRecord::Migration
  def change
    remove_column :call_data_records, :body
  end
end
