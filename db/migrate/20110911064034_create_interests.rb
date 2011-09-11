class CreateInterests < ActiveRecord::Migration
  def change
    create_table :interests do |t|
      t.string :value

      t.timestamps
    end
  end
end
