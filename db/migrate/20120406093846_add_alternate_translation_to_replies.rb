class AddAlternateTranslationToReplies < ActiveRecord::Migration
  def change
    add_column :replies, :alternate_translation, :text
    add_column :replies, :locale, :string, :limit => 2
  end
end
