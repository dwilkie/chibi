class CreateCallDataRecords < ActiveRecord::Migration
  def change
    create_table :call_data_records do |t|
      t.text       :body
      t.string     :uuid
      t.integer    :duration
      t.integer    :bill_sec
      t.datetime   :rfc2822_date
      t.string     :direction
      t.references :phone_call
      t.timestamps
    end

    add_index :call_data_records, :phone_call_id, :unique => true
    add_index :call_data_records, :uuid, :unique => true
  end
end
