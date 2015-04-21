class AddDurationToPhoneCalls < ActiveRecord::Migration
  def change
    add_column(:phone_calls, :duration, :integer)
  end
end
