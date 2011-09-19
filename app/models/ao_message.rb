class AoMessage < ActiveRecord::Base
  belongs_to :subscription
  after_create :deliver!

  attr_accessible :body

  def deliver!
    Nuntium.send_mt attributes.slice("body").merge("to" => user.mobile_number)
  end

end

