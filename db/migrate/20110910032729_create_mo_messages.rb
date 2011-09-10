class CreateMoMessages < ActiveRecord::Migration
  def change
    create_table :mo_messages do |t|
      t.string "message"
      t.string "sender"
      t.string "guid"
      t.timestamps
    end
  end
end

