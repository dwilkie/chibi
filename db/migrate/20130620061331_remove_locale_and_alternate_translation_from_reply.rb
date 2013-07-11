class RemoveLocaleAndAlternateTranslationFromReply < ActiveRecord::Migration
  def change
    remove_column :replies, :locale
    remove_column :replies, :alternate_translation
  end
end
