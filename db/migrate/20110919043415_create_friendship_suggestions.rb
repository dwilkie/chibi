class CreateFriendshipSuggestions < ActiveRecord::Migration
  def change
    create_table :friendship_suggestions do |t|
      t.references :user
      t.references :suggested_friend
      t.timestamps
    end
  end
end

