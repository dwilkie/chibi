class DropOldTables < ActiveRecord::Migration
  def up
    drop_table :interests
    drop_table :mo_messages
    drop_table :mt_messages
    drop_table :user_interests
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
