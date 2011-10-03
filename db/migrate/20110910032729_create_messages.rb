class CreateMessages < ActiveRecord::Migration
  def change
    create_table :messages do |t|
      t.string     :from
      t.string     :body
      t.references :subscription
      t.timestamps
    end

    add_index :messages, :subscription_id
  end
end

