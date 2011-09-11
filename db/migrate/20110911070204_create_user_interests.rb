class CreateUserInterests < ActiveRecord::Migration
  def change
    create_table :user_interests, :id => false do |t|
      t.integer :user_id
      t.integer :interest_id
    end
  end
end
