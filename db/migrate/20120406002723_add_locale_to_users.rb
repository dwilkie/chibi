class AddLocaleToUsers < ActiveRecord::Migration
  def change
    add_column :users, :locale, :string, :limit => 2
  end
end
