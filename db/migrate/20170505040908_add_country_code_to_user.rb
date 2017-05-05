class AddCountryCodeToUser < ActiveRecord::Migration
  def up
    add_column(:users, :country_code, :string, :limit => 2)
    add_index(:users, :country_code)
    ActiveRecord::Base.connection.execute("UPDATE users SET country_code = locations.country_code FROM locations WHERE locations.user_id = users.id")
    change_column(:users, :country_code, :string, :limit => 2, :null => false)
  end

  def down
    remove_column(:users, :country_code)
  end
end
