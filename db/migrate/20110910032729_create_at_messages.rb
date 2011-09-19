class CreateAtMessages < ActiveRecord::Migration
  def change
    create_table :at_messages do |t|
      t.string     :from
      t.string     :body
      t.references :subscription
      t.timestamps
    end
  end
end

