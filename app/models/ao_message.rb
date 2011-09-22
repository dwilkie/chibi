class AoMessage < ActiveRecord::Base
  belongs_to :subscription

  attr_accessible :body

  def deliver!
    Nuntium.send_mt attributes.slice("body").merge("to" => user.mobile_number)
  end

end

