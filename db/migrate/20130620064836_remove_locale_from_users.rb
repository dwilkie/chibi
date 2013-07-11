class RemoveLocaleFromUsers < ActiveRecord::Migration
  def change
    remove_column :users, :locale
  end
end
