class CreateMoMessages < ActiveRecord::Migration
  def change
    create_table :mo_messages do |t|
      t.string     :from
      t.string     :body
      t.string     :guid
      t.references :user
      t.timestamps
    end
  end
end

