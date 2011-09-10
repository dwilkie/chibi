class CreateMtMessages < ActiveRecord::Migration
  def change
    create_table :mt_messages do |t|
      t.string "to"
      t.string "body"
      t.timestamps
    end
  end
end

