class AddBodyToCallDataRecords < ActiveRecord::Migration
  def change
    add_column(:call_data_records, :body, :jsonb)
  end
end
