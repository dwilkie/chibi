class CreateReplies < ActiveRecord::Migration
  def change
    create_table :replies do |t|
      t.string      :to
      t.string      :body
      t.boolean     :read,          :default => false
      t.references  :subscription
      t.references  :chat
      t.timestamps
    end

    add_index :replies,      :subscription_id
    add_index :replies,      :chat_id
  end
end

