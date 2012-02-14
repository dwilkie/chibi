class CreateMessages < ActiveRecord::Migration
  def change
    create_table :messages do |t|
      t.string     :from
      t.string     :body
      t.references :user
      t.references :chat
      t.timestamps
    end

    add_index :messages, :user_id
    add_index :messages, :chat_id
  end
end
