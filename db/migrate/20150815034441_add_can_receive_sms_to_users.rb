class AddCanReceiveSmsToUsers < ActiveRecord::Migration
  def change
    add_column(:users, :can_receive_sms, :boolean, :null => false, :default => true)
    landline_prefixes = Torasup.prefixes.select { |prefix, data| data["type"] == "landline" }.keys
    seven_digit_landline_prefixes = landline_prefixes.select { |prefix| prefix.length == 7 }
    six_digit_landline_prefixes = landline_prefixes.select { |prefix| prefix.length == 6 }

    seven_digit_update_statement = seven_digit_landline_prefixes.map { |prefix| "mobile_number LIKE '#{prefix}%'" }.join(" OR ")
    six_digit_update_statement = six_digit_landline_prefixes.map { |prefix| "mobile_number LIKE '#{prefix}%'" }.join(" OR ")

    User.where(seven_digit_update_statement).update_all(:can_receive_sms => false)
    User.where(six_digit_update_statement).update_all(:can_receive_sms => false)
  end
end
