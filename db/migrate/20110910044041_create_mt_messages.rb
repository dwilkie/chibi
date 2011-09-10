class CreateMtMessages < ActiveRecord::Migration
  def change
    create_table :mt_messages do |t|

      t.timestamps
    end
  end
end

