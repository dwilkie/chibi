class AddToAndChannelToMessages < ActiveRecord::Migration
  def change
    add_column(:messages, :to, :string)
    add_column(:messages, :channel, :string)
  end
end
