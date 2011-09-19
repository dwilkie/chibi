class CreateAoMessages < ActiveRecord::Migration
  def change
    create_table :ao_messages do |t|
      t.string      :body
      t.references  :subscription
      t.timestamps
    end
  end
end

