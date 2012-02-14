class CreateReplies < ActiveRecord::Migration
  def change
    create_table :replies do |t|
      t.string      :to
      t.string      :body
      t.boolean     :read,          :default => false
      t.integer     :priority
      t.references  :user
      t.references  :chat
      t.timestamps
    end

    add_index :replies,  :user_id
    add_index :replies,  :chat_id
    add_index :replies,  :read
    add_index :replies,  :priority
  end
end
