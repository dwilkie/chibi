class CreateMessageParts < ActiveRecord::Migration
  def change
    create_table :message_parts do |t|
      t.string :body, :null => false
      t.integer :sequence_number, :null => false
      t.references :message, :null => false

      t.timestamps :null => false
    end

    add_index :message_parts, :message_id
  end
end
