class Reply < ActiveRecord::Base
  belongs_to :message
  belongs_to :subscription

  attr_accessible :body, :subscription

  def deliver!
    Nuntium.send_mt attributes.slice("body").merge("to" => user.mobile_number)
  end

end

