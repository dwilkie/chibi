class CreateUserMatches < ActiveRecord::Migration
  def change
    create_table :user_matches do |t|
      t.references :user
      t.references :suggested_friend_id
      t.timestamps
    end
  end
end

