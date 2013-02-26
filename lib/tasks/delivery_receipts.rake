namespace :delivery_receipts do
  desc "Sets the replies state from the delivery receipts associated"
  task :set_reply_states => :environment do
    Resque.enqueue(ReplyStateSetter)
  end
end
