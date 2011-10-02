class CreateReplies < ActiveRecord::Migration
  def change
    create_table :replies do |t|
      t.string      :body
      t.references  :message
      t.references  :subscription
      t.timestamps
    end
  end
end

