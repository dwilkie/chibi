class CreateInterests < ActiveRecord::Migration
  def change
    create_table :interests do |t|
      t.string :description

      t.timestamps
    end
  end
end

