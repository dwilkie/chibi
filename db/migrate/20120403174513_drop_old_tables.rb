class DropOldTables < ActiveRecord::Migration
  def up
    connection = ActiveRecord::Base.connection
    drop_table :interests if connection.table_exists?(:interests)
    drop_table :mo_messages if connection.table_exists?(:mo_messages)
    drop_table :mt_messages if connection.table_exists?(:mt_messages)
    drop_table :user_interests if connection.table_exists?(:user_interests)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
