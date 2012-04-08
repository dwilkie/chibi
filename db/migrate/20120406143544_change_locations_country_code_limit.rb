class ChangeLocationsCountryCodeLimit < ActiveRecord::Migration
  def up
    change_column :locations, :country_code, :string, :limit => 2
  end

  def down
    change_column :locations, :country_code, :string
  end
end
