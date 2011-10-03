class CreateReplies < ActiveRecord::Migration
  def change
    create_table :replies do |t|
      t.string      :body
      t.references  :message
      t.references  :subscription
      t.timestamps
    end

    add_index :replies,      :message_id
    add_index :replies,      :subscription_id
  end
end

