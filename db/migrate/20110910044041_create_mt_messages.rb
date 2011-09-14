class CreateMtMessages < ActiveRecord::Migration
  def change
    create_table :mt_messages do |t|
      t.string      :body
      t.references  :user
      t.timestamps
    end
  end
end

