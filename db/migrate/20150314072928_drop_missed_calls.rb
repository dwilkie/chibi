class DropMissedCalls < ActiveRecord::Migration
  def change
    drop_table(:missed_calls)
  end
end
