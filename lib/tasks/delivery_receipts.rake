namespace :delivery_receipts do
  desc "Sets the replies state from the delivery receipts associated"
  task :set_reply_states => :environment do
    DeliveryReceipt.set_reply_states!
  end
end
