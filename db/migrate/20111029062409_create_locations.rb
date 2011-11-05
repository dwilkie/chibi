class CreateLocations < ActiveRecord::Migration
  def change
    create_table :locations do |t|
      t.string     :city
      t.string     :country_code
      t.float      :latitude
      t.float      :longitude
      t.references :user
      t.timestamps
    end
  end
end
