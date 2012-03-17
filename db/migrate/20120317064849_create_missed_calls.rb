class CreateMissedCalls < ActiveRecord::Migration
  def change
    create_table :missed_calls do |t|
      t.string :from
      t.references :user
      t.timestamps
    end

    add_index :missed_calls, :user_id
  end
end
