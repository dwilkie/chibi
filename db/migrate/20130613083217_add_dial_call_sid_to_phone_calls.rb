class AddDialCallSidToPhoneCalls < ActiveRecord::Migration
  def change
    add_column :phone_calls, :dial_call_sid, :string
    add_index  :phone_calls, :dial_call_sid, :unique => true
  end
end
