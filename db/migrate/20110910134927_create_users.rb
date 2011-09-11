class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :phone_number
      t.string :profile
      t.string :status, :default => 'newbie'

      t.timestamps
    end
  end
end
